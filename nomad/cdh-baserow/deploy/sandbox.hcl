#############################
# Nomad Job: CDH Baserow (sandbox) — behind NGINX Plus
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

# Public URL seen by users (set to your HTTPS host)
variable "BASEROW_PUBLIC_URL" {
  type    = string
  default = "https://cdh-baserow-sandbox.lib.princeton.edu"
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

# Caddy host storage (for /config and /data)
variable "HOST_CADDY_PARENT" {
  type    = string
  default = "/srv/nomad/host_volumes"
}

variable "HOST_CADDY_CONFIG_DIR" {
  type    = string
  default = "cdh-baserow-caddy-config"
}

variable "HOST_CADDY_DATA_DIR" {
  type    = string
  default = "cdh-baserow-caddy-data"
}

# Caddy (HTTP-only behind NGINX Plus)
variable "BASEROW_CADDY_ADDRESSES" {
  type    = string
  default = ":80"
}

variable "BASEROW_CADDY_GLOBAL_CONF" {
  type    = string
  default = ""
}

variable "MEDIA_ROOT" {
  type    = string
  default = "/baserow/media"
}

variable "STATIC_ROOT" {
  type    = string
  default = "/baserow/static"
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
      # Web-frontend (Nuxt)
      port "web" { to = 3000 }
      # Backend (Django/ASGI)
      port "api" { to = 8000 }
      # Public listener that NGINX Plus will hit
      port "http" { to = 80 }

      dns {
        servers = ["10.88.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    # Internal health services
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

    # Public service *for NGINX Plus*: single HTTP endpoint
    service {
      name = "cdh-baserow-sandbox"
      port = "http"
      check {
        type     = "http"
        port     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    # Prepare host dirs for media (owned by Django uid/gid 9999)
    task "prepare-media-dir" {
      driver = "podman"
      user   = "root"

      config {
        image   = "docker.io/library/bash:4.4"
        command = "bash"
        args    = ["-c", "mkdir -p /host/${var.HOST_MEDIA_DIR} && chown 9999:9999 -R /host/${var.HOST_MEDIA_DIR}"]
        volumes = ["${var.HOST_MEDIA_PARENT}:/host"]
      }

      lifecycle {
        hook = "prestart"
      }
      
      resources {
        cpu    = 50
        memory = 64
      }
    }

    # Prepare host dirs for Caddy state
    task "prepare-caddy-dirs" {
      driver = "podman"
      user   = "root"

      config {
        image   = "docker.io/library/bash:4.4"
        command = "bash"
        args    = ["-c", "mkdir -p /host/${var.HOST_CADDY_CONFIG_DIR} /host/${var.HOST_CADDY_DATA_DIR}"]
        volumes = ["${var.HOST_CADDY_PARENT}:/host"]
      }

      lifecycle {
        hook = "prestart"
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

      env {
        BASEROW_PUBLIC_URL                      = var.BASEROW_PUBLIC_URL
        BASEROW_ENABLE_SECURE_PROXY_SSL_HEADER  = "yes"
        FROM_EMAIL                               = "cdh-baserow@princeton.edu"
        EMAIL_SMTP                              = "smtp.princeton.edu"
        EMAIL_SMTP_HOST                          = "smtp.princeton.edu"
        EMAIL_SMTP_PORT                          = "587"
        EMAIL_SMTP_USE_TLS                       = "true"
        DJANGO_SETTINGS_MODULE                   = "baserow.config.settings.base"
        BASEROW_AMOUNT_OF_WORKERS                = "1"
        BASEROW_WEB_FRONTEND_PORT                = "3000"
        BASEROW_BACKEND_PORT                     = "8000"
        GUNICORN_BIND                           = "0.0.0.0:8000"
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

      env {
        BASEROW_PUBLIC_URL  = var.BASEROW_PUBLIC_URL
        PRIVATE_BACKEND_URL = "http://${NOMAD_ADDR_api}"
        NUXT_HOST          = "0.0.0.0"
        NUXT_PORT          = "3000"
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
        args    = ["celery-worker"]
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
        args    = ["celery-exportworker"]
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
      driver      = "podman"
      kill_signal = "SIGQUIT"

      config {
        image   = "${var.backend_image_repo}:${var.backend_image_tag}"
        args    = ["celery-beat"]
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

    # --- Caddy reverse proxy (HTTP-only; NGINX Plus handles TLS & LB) ---
    task "caddy" {
      driver = "podman"

      config {
        image = "docker.io/library/caddy:2"
        ports = ["http"]
        volumes = [
          "local:/etc/caddy",
          "${var.HOST_MEDIA_PARENT}/${var.HOST_MEDIA_DIR}:/baserow/media",
          "${var.HOST_CADDY_PARENT}/${var.HOST_CADDY_CONFIG_DIR}:/config",
          "${var.HOST_CADDY_PARENT}/${var.HOST_CADDY_DATA_DIR}:/data",
        ]
      }

      template {
        destination = "local/Caddyfile"
        change_mode = "restart"
        data = <<EOT
{{ env "BASEROW_CADDY_GLOBAL_CONF" }}

{{ env "BASEROW_CADDY_ADDRESSES" }} {
  # No TLS here; NGINX Plus terminates HTTPS and forwards headers
  
  handle /api/* {
    reverse_proxy {{ env "NOMAD_ADDR_api" }}
  }
  
  handle /ws/* {
    reverse_proxy {{ env "NOMAD_ADDR_api" }}
  }
  
  handle_path /media/* {
    @downloads {
      query dl=*
    }
    header @downloads Content-disposition "attachment; filename={query.dl}"
    file_server {
      root {{ env "MEDIA_ROOT" }}
    }
  }

  handle_path /static/* {
    file_server {
      root {{ env "STATIC_ROOT" }}
    }
  }
  
  # everything else -> web-frontend
  reverse_proxy {{ env "NOMAD_ADDR_web" }}
}
EOT
      }

      env {
        BASEROW_CADDY_ADDRESSES   = var.BASEROW_CADDY_ADDRESSES
        BASEROW_CADDY_GLOBAL_CONF = var.BASEROW_CADDY_GLOBAL_CONF
        MEDIA_ROOT                = var.MEDIA_ROOT
        STATIC_ROOT               = var.STATIC_ROOT
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
