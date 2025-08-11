#############################
# Nomad Job: CDH Baserow (sandbox)
#############################

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

# we seem to expect -var branch_or_sha=…
variable "branch_or_sha" {
  type    = string
  default = ""
}

# App (non-secret) vars
variable "BASEROW_PUBLIC_URL" {
  type    = string
  default = "http://localhost"
}
variable "PRIVATE_BACKEND_URL" {
  type    = string
  default = "http://localhost:8000"
}

# Media bind mount parts (parent must exist on host; set to a known path)
variable "HOST_MEDIA_PARENT" {
  type    = string
  default = "/srv/nomad/host_volumes"
}
variable "HOST_MEDIA_DIR" {
  type    = string
  default = "cdh-baserow-media"
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
      port "web" {
        to = 3000
      }
      port "api" {
        to = 8000
      }
      dns {
        servers = ["10.88.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

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

    # Prepare the media directory using Podman only:
    # mount the PARENT at /host, then mkdir/chown the child dir inside it.
    task "prepare-media-dir" {
      driver = "podman"
      user   = "root"

      config {
        image   = "docker.io/library/bash:4.4"
        command = "bash"
        args    = [
          "-lc",
          "mkdir -p /host/${var.HOST_MEDIA_DIR} && chown 9999:9999 -R /host/${var.HOST_MEDIA_DIR}"
        ]
        volumes = ["${var.HOST_MEDIA_PARENT}:/host"]
      }

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      resources {
        cpu    = 50
        memory = 64
      }
    }

    # --- Backend (Django/ASGI) ---
    task "backend" {
      driver = "podman"

      config {
        image   = "${var.backend_image_repo}:${var.backend_image_tag}"
        ports   = ["api"]
        volumes = ["${var.HOST_MEDIA_PARENT}/${var.HOST_MEDIA_DIR}:/baserow/media"]
      }

      # Secrets + DB/Redis from Nomad vars (underscore path)
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
        volumes = ["${var.HOST_MEDIA_PARENT}/${var.HOST_MEDIA_DIR}:/baserow/media"]
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
        volumes = ["${var.HOST_MEDIA_PARENT}/${var.HOST_MEDIA_DIR}:/baserow/media"]
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
        volumes = ["${var.HOST_MEDIA_PARENT}/${var.HOST_MEDIA_DIR}:/baserow/media"]
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
