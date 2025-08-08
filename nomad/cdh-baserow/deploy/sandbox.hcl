#############################
# Nomad Job: CDH Baserow    #
#############################

# Variables for Baserow environment
variable "branch_or_sha" {
  type    = string
  default = "main"
}

variable "SECRET_KEY" {
  type = string
}
variable "BASEROW_JWT_SIGNING_KEY" {
  type    = string
  default = ""
}
variable "DATABASE_PASSWORD" {
  type = string
}
variable "REDIS_PASSWORD" {
  type = string
}

variable "REDIS_HOST" {
  type    = string
  default = "lib-redis-sandbox1.princeton.edu"
}
variable "REDIS_PORT" { type = number default = 6379 }

variable "BASEROW_PUBLIC_URL" {
  type    = string
  default = ""
}

variable "DATABASE_HOST" {
  type    = string
  default = "lib-postgres-sandbox1.princeton.edu"
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

variable "backend_image_repo" {
  type    = string
  default = "docker.io/baserow/backend"
}
variable "web_image_repo"     { type = string default = "docker.io/baserow/web-frontend" }

job "cdh-baserow" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "sandbox"

  volume "media" {
    type      = "host"
    source    = "media"
    read_only = false
  }

  update {
    canary       = 1
    auto_promote = true
    auto_revert  = true
  }

  group "services" {
    count = 1

    network {
      mode = "bridge"
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

    template {
      destination = "${NOMAD_SECRETS_DIR}/env.vars"
      env         = true
      change_mode = "restart"
      data = <<EOF
      {{- with nomadVar "nomad/jobs/cdh-baserow" -}}
      SECRET_KEY = {{ .SECRET_KEY }}
      BASEROW_JWT_SIGNING_KEY = {{ .BASEROW_JWT_SIGNING_KEY }}
      DATABASE_PASSWORD = {{ .DATABASE_PASSWORD }}
      REDIS_PASSWORD = {{ .REDIS_PASSWORD }}
      {{- end -}}
      EOF
    }

    task "volume-permissions-fixer" {
      driver = "podman"
      user   = "root"
      config {
        image = "docker.io/library/bash:4.4"
        command = "chown"
        args    = ["9999:9999", "-R", "/baserow/media"]
      }
      volume_mount {
        volume      = "media"
        destination = "/baserow/media"
        read_only   = false
      }
      lifecycle { hook = "prestart" sidecar = false }
      resources { cpu = 100 memory = 64 }
    }

    task "backend" {
      driver = "podman"
      config {
        image = "${var.backend_image_repo}:sha-${var.branch_or_sha}"
        ports = ["api"]
      }
      env = {
        BASEROW_PUBLIC_URL      = var.BASEROW_PUBLIC_URL
        SECRET_KEY              = var.SECRET_KEY
        BASEROW_JWT_SIGNING_KEY = var.BASEROW_JWT_SIGNING_KEY
        DATABASE_HOST           = var.DATABASE_HOST
        DATABASE_USER           = var.DATABASE_USER
        DATABASE_NAME           = var.DATABASE_NAME
        DATABASE_PASSWORD       = var.DATABASE_PASSWORD
        REDIS_HOST              = var.REDIS_HOST
        REDIS_PORT              = tostring(var.REDIS_PORT)
        REDIS_PASSWORD          = var.REDIS_PASSWORD
      }
      volume_mount {
        volume      = "media"
        destination = "/baserow/media"
        read_only   = false
      }
      resources { cpu = 1000 memory = 1024 }
    }

    task "web-frontend" {
      driver = "podman"
      config {
        image = "${var.web_image_repo}:sha-${var.branch_or_sha}"
        ports = ["web"]
      }
      env = {
        BASEROW_PUBLIC_URL  = var.BASEROW_PUBLIC_URL
        PRIVATE_BACKEND_URL = var.PRIVATE_BACKEND_URL
      }
      resources { cpu = 500 memory = 512 }
    }

    task "celery-worker" {
      driver = "podman"
      config {
        image   = "${var.backend_image_repo}:sha-${var.branch_or_sha}"
        command = ["celery-worker"]
      }
      env = {
        SECRET_KEY              = var.SECRET_KEY
        BASEROW_JWT_SIGNING_KEY = var.BASEROW_JWT_SIGNING_KEY
        DATABASE_HOST           = var.DATABASE_HOST
        DATABASE_USER           = var.DATABASE_USER
        DATABASE_NAME           = var.DATABASE_NAME
        DATABASE_PASSWORD       = var.DATABASE_PASSWORD
        REDIS_HOST              = var.REDIS_HOST
        REDIS_PORT              = tostring(var.REDIS_PORT)
        REDIS_PASSWORD          = var.REDIS_PASSWORD
      }
      volume_mount {
        volume      = "media"
        destination = "/baserow/media"
        read_only   = false
      }
      resources { cpu = 500 memory = 512 }
    }

    task "celery-export" {
      driver = "podman"
      config {
        image   = "${var.backend_image_repo}:sha-${var.branch_or_sha}"
        command = ["celery-exportworker"]
      }
      env = {
        SECRET_KEY              = var.SECRET_KEY
        BASEROW_JWT_SIGNING_KEY = var.BASEROW_JWT_SIGNING_KEY
        DATABASE_HOST           = var.DATABASE_HOST
        DATABASE_USER           = var.DATABASE_USER
        DATABASE_NAME           = var.DATABASE_NAME
        DATABASE_PASSWORD       = var.DATABASE_PASSWORD
        REDIS_HOST              = var.REDIS_HOST
        REDIS_PORT              = tostring(var.REDIS_PORT)
        REDIS_PASSWORD          = var.REDIS_PASSWORD
      }
      volume_mount {
        volume      = "media"
        destination = "/baserow/media"
        read_only   = false
      }
      resources { cpu = 500 memory = 512 }
    }

    task "celery-beat" {
      driver = "podman"
      config {
        image       = "${var.backend_image_repo}:sha-${var.branch_or_sha}"
        command     = ["celery-beat"]
      }
      env = {
        SECRET_KEY              = var.SECRET_KEY
        BASEROW_JWT_SIGNING_KEY = var.BASEROW_JWT_SIGNING_KEY
        DATABASE_HOST           = var.DATABASE_HOST
        DATABASE_USER           = var.DATABASE_USER
        DATABASE_NAME           = var.DATABASE_NAME
        DATABASE_PASSWORD       = var.DATABASE_PASSWORD
        REDIS_HOST              = var.REDIS_HOST
        REDIS_PORT              = tostring(var.REDIS_PORT)
        REDIS_PASSWORD          = var.REDIS_PASSWORD
      }
      volume_mount {
        volume      = "media"
        destination = "/baserow/media"
        read_only   = false
      }
      resources { cpu = 200 memory = 256 }
    }
  }
}

