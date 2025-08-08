#############################
# Nomad Job: CDH Baserow (sandbox)
#############################

# --- Image selection (branch/SHA style) ---
variable "branch_or_sha" {
  type    = string
  default = "main"
}

variable "image_tag_prefix" {
  type    = string
  default = ""
}

variable "backend_image_repo" {
  type    = string
  default = "docker.io/baserow/backend"
}

variable "web_image_repo" {
  type    = string
  default = "docker.io/baserow/web-frontend"
}

# --- Non-secret app config variables ---
variable "REDIS_HOST" {
  type    = string
  default = "lib-redis-staging1.princeton.edu"
}

variable "REDIS_PORT" {
  type    = string
  default = "6379"
}

variable "BASEROW_PUBLIC_URL" {
  type    = string
  default = ""
}

variable "DATABASE_HOST" {
  type    = string
  default = "lib-postgres-staging1.princeton.edu"
}

variable "DATABASE_USER" {
  type    = string
  default = "baserow"
}

variable "DATABASE_NAME" {
  type    = string
  default = "baserow"
}

variable "PRIVATE_BACKEND_URL" {
  type    = string
  default = "http://localhost:8000"
}

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

    task "backend" {
      driver = "podman"

      config {
        image   = "${var.backend_image_repo}:${var.image_tag_prefix}${var.branch_or_sha}"
        ports   = ["api"]
        volumes = ["${var.HOST_MEDIA_PATH}:/baserow/media"]
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env         = true
        change_mode = "restart"
        data = <<EOF
{{- with nomadVar "nomad/jobs/cdh-baserow-sandbox" -}}
SECRET_KEY = {{ .SECRET_KEY }}
BASEROW_JWT_SIGNING_KEY = {{ .BASEROW_JWT_SIGNING_KEY }}
DATABASE_PASSWORD = {{ .DATABASE_PASSWORD }}
REDIS_PASSWORD = {{ .REDIS_PASSWORD }}
{{- end -}}
EOF
      }

      env = {
        BASEROW_PUBLIC_URL = var.BASEROW_PUBLIC_URL
        DATABASE_HOST      = var.DATABASE_HOST
        DATABASE_USER      = var.DATABASE_USER
        DATABASE_NAME      = var.DATABASE_NAME
        REDIS_HOST         = var.REDIS_HOST
        REDIS_PORT         = var.REDIS_PORT
      }

      resources {
        cpu    = 1000
        memory = 1024
      }
    }

    task "web-frontend" {
      driver = "podman"

      config {
        image   = "${var.web_image_repo}:${var.image_tag_prefix}${var.branch_or_sha}"
        ports   = ["web"]
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

    task "celery-worker" {
      driver = "podman"

      config {
        image   = "${var.backend_image_repo}:${var.image_tag_prefix}${var.branch_or_sha}"
        command = ["celery-worker"]
        volumes = ["${var.HOST_MEDIA_PATH}:/baserow/media"]
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env         = true
        change_mode = "restart"
        data = <<EOF
{{- with nomadVar "nomad/jobs/cdh-baserow-sandbox" -}}
SECRET_KEY = {{ .SECRET_KEY }}
BASEROW_JWT_SIGNING_KEY = {{ .BASEROW_JWT_SIGNING_KEY }}
DATABASE_PASSWORD = {{ .DATABASE_PASSWORD }}
REDIS_PASSWORD = {{ .REDIS_PASSWORD }}
{{- end -}}
EOF
      }

      env = {
        DATABASE_HOST = var.DATABASE_HOST
        DATABASE_USER = var.DATABASE_USER
        DATABASE_NAME = var.DATABASE_NAME
        REDIS_HOST    = var.REDIS_HOST
        REDIS_PORT    = var.REDIS_PORT
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }

    task "celery-export" {
      driver = "podman"

      config {
        image   = "${var.backend_image_repo}:${var.image_tag_prefix}${var.branch_or_sha}"
        command = ["celery-exportworker"]
        volumes = ["${var.HOST_MEDIA_PATH}:/baserow/media"]
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env         = true
        change_mode = "restart"
        data = <<EOF
{{- with nomadVar "nomad/jobs/cdh-baserow-sandbox" -}}
SECRET_KEY = {{ .SECRET_KEY }}
BASEROW_JWT_SIGNING_KEY = {{ .BASEROW_JWT_SIGNING_KEY }}
DATABASE_PASSWORD = {{ .DATABASE_PASSWORD }}
REDIS_PASSWORD = {{ .REDIS_PASSWORD }}
{{- end -}}
EOF
      }

      env = {
        DATABASE_HOST = var.DATABASE_HOST
        DATABASE_USER = var.DATABASE_USER
        DATABASE_NAME = var.DATABASE_NAME
        REDIS_HOST    = var.REDIS_HOST
        REDIS_PORT    = var.REDIS_PORT
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }

    task "celery-beat" {
      driver = "podman"

      config {
        image   = "${var.backend_image_repo}:${var.image_tag_prefix}${var.branch_or_sha}"
        command = ["celery-beat"]
        volumes = ["${var.HOST_MEDIA_PATH}:/baserow/media"]
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env         = true
        change_mode = "restart"
        data = <<EOF
{{- with nomadVar "nomad/jobs/cdh-baserow-sandbox" -}}
SECRET_KEY = {{ .SECRET_KEY }}
BASEROW_JWT_SIGNING_KEY = {{ .BASEROW_JWT_SIGNING_KEY }}
DATABASE_PASSWORD = {{ .DATABASE_PASSWORD }}
REDIS_PASSWORD = {{ .REDIS_PASSWORD }}
{{- end -}}
EOF
      }

      env = {
        DATABASE_HOST = var.DATABASE_HOST
        DATABASE_USER = var.DATABASE_USER
        DATABASE_NAME = var.DATABASE_NAME
        REDIS_HOST    = var.REDIS_HOST
        REDIS_PORT    = var.REDIS_PORT
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}

