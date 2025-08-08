#############################
# Nomad Job: CDH Baserow (sandbox)
#############################

# --- Image pinning (release tags) ---
variable "backend_image_repo" {
  type    = string
  default = "docker.io/baserow/backend"
}
variable "backend_image_tag" {
  type    = string
  default = "1.34.5"
}
variable "web_image_repo" {
  type    = string
  default = "docker.io/baserow/web-frontend"
}
variable "web_image_tag" {
  type    = string
  default = "1.34.5"
}

# --- App config (non-secrets) ---
variable "BASEROW_PUBLIC_URL" {
  type    = string
  default = ""
}
variable "PRIVATE_BACKEND_URL" {
  type    = string
  default = "http://localhost:8000"
}

# Host path for persistent uploads (bind-mounted into tasks)
variable "HOST_MEDIA_PATH" {
  type    = string
  default = "/srv/nomad/host_volumes/cdh-baserow-media"
}

job "cdh-baserow" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "sandbox"

  group "services" {
    count = 1

    update {
      canary       = 1
      auto_promote = true
      auto_revert  = true
    }

    network {
      port "web" { to = 3000 }
      port "api" { to = 8000 }

      dns {
        servers = ["10.88.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    # Register services (group-level) for Consul
    service {
      name = "cdh-baserow-web"
      port = "web"
      check {
        type     = "http"
        port     = "web"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }
    service {
      name = "cdh-baserow-backend"
      port = "api"
      check {
        type     = "http"
        port     = "api"
        path     = "/healthz"
        interval = "10s"
        timeout  = "2s"
      }
    }

    # Ensure host media directory exists before we bind-mount it
    task "ensure-media-dir" {
      driver = "raw_exec"
      config {
        command = "/bin/mkdir"
        args    = ["-p", "${var.HOST_MEDIA_PATH}"]
      }
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }
      resources {
        cpu    = 50
        memory = 16
      }
    }

    # Fix media volume permissions for Django UID 9999
    task "volume-permissions-fixer" {
      driver = "podman"
      user   = "root"
      config {
        image   = "docker.io/library/bash:4.4"
        command = "chown"
        args    = ["9999:9999", "-R", "/baserow/media"]
        volumes = ["${var.HOST_MEDIA_PATH}:/baserow/media"]
      }
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }
      resources {
        cpu    = 100
        memory = 64
      }
    }

    # --- Backend (Django/ASGI) ---
    task "backend" {
      driver = "podman"
      config {
        image   = "${var.backend_image_repo}:${var.backend_image_tag}"
        ports   = ["api"]
        volumes = ["${var.HOST_MEDIA_PATH}:/baserow/media"]
      }

      # Secrets + DB/Redis from Nomad KV (underscore path!)
      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env         = true
        change_mode = "restart"
        data = <<EOF
{{- with nomadVar "nomad/jobs/cdh_baserow-sandbox" -}}
SECRET_KEY = {{ .SECRET_KEY }}
BASEROW_JWT_SIGNING_KEY = {{ .BASEROW_JWT_SIGNING_KEY }}

# Database
DATABASE_HOST = {{ .POSTGRES_HOST }}
DATABASE_USER = {{ .DB_USER }}
DATABASE_NAME = {{ .DB_NAME }}
DATABASE_PASSWORD = {{ .DB_PASSWORD }}

# Redis
REDIS_HOST = {{ .REDIS_HOST }}
REDIS_PORT = {{ .REDIS_PORT }}
REDIS_PASSWORD = {{ .REDIS_PASSWORD }}
{{- end -}}
EOF
      }

      # Stable non-secrets here
      env = {
        BASEROW_PUBLIC_URL = var.BASEROW_PUBLIC_URL
      }

      resources {
        cpu    = 1000
        memory = 1024
      }
    }

    # --- Web frontend ---
    task "web-frontend" {
      driver = "podman"
      config {
        image = "${var.web_image_repo}:${var.web_image_tag}"
        ports = ["web"]
      }
      env = {
        BASEROW_PUBLIC_URL  = var.BASEROW_PUBLIC_URL
        PRIVATE_BACKEND_URL = var.PRIVATE_BACKEND_URL
      }
      resources {
        cpu    = 500
        memory = 512
      }
    }

    # --- Celery worker ---
    task "celery-worker" {
      driver = "podman"
      config {
        image   = "${var.backend_image_repo}:${var.backend_image_tag}"
        command = ["celery-worker"]
        volumes = ["${var.HOST_MEDIA_PATH}:/baserow/media"]
      }
      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env         = true
        change_mode = "restart"
        data = <<EOF
{{- with nomadVar "nomad/jobs/cdh_baserow-sandbox" -}}
SECRET_KEY = {{ .SECRET_KEY }}
BASEROW_JWT_SIGNING_KEY = {{ .BASEROW_JWT_SIGNING_KEY }}
DATABASE_HOST = {{ .POSTGRES_HOST }}
DATABASE_USER = {{ .DB_USER }}
DATABASE_NAME = {{ .DB_NAME }}
DATABASE_PASSWORD = {{ .DB_PASSWORD }}
REDIS_HOST = {{ .REDIS_HOST }}
REDIS_PORT = {{ .REDIS_PORT }}
REDIS_PASSWORD = {{ .REDIS_PASSWORD }}
{{- end -}}
EOF
      }
      resources {
        cpu    = 500
        memory = 512
      }
    }

    # --- Celery export worker ---
    task "celery-export" {
      driver = "podman"
      config {
        image   = "${var.backend_image_repo}:${var.backend_image_tag}"
        command = ["celery-exportworker"]
        volumes = ["${var.HOST_MEDIA_PATH}:/baserow/media"]
      }
      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env         = true
        change_mode = "restart"
        data = <<EOF
{{- with nomadVar "nomad/jobs/cdh_baserow-sandbox" -}}
SECRET_KEY = {{ .SECRET_KEY }}
BASEROW_JWT_SIGNING_KEY = {{ .BASEROW_JWT_SIGNING_KEY }}
DATABASE_HOST = {{ .POSTGRES_HOST }}
DATABASE_USER = {{ .DB_USER }}
DATABASE_NAME = {{ .DB_NAME }}
DATABASE_PASSWORD = {{ .DB_PASSWORD }}
REDIS_HOST = {{ .REDIS_HOST }}
REDIS_PORT = {{ .REDIS_PORT }}
REDIS_PASSWORD = {{ .REDIS_PASSWORD }}
{{- end -}}
EOF
      }
      resources {
        cpu    = 500
        memory = 512
      }
    }

    # --- Celery beat ---
    task "celery-beat" {
      driver = "podman"
      config {
        image   = "${var.backend_image_repo}:${var.backend_image_tag}"
        command = ["celery-beat"]
        volumes = ["${var.HOST_MEDIA_PATH}:/baserow/media"]
      }
      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env         = true
        change_mode = "restart"
        data = <<EOF
{{- with nomadVar "nomad/jobs/cdh_baserow-sandbox" -}}
SECRET_KEY = {{ .SECRET_KEY }}
BASEROW_JWT_SIGNING_KEY = {{ .BASEROW_JWT_SIGNING_KEY }}
DATABASE_HOST = {{ .POSTGRES_HOST }}
DATABASE_USER = {{ .DB_USER }}
DATABASE_NAME = {{ .DB_NAME }}
DATABASE_PASSWORD = {{ .DB_PASSWORD }}
REDIS_HOST = {{ .REDIS_HOST }}
REDIS_PORT = {{ .REDIS_PORT }}
REDIS_PASSWORD = {{ .REDIS_PASSWORD }}
{{- end -}}
EOF
      }
      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
