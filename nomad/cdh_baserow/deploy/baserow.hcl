#############################
# Nomad Job: CDH Baserow       #
#############################
# used nomad `raw_exec`
# to convert
# https://gitlab.com/baserow/baserow/-/raw/develop/docker-compose.yml

# Variables for Baserow environment
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
  default = "lib-redis-staging1.princeton.edu"
}

variable "REDIS_PORT" {
  type    = number
  default = 6379
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

job "cdh-baserow" {
  datacenters = ["dc1"]
  type        = "service"

  # Host-backed volumes
  volume "media" {
    type   = "host"
    source = "media"
  }

  group "services" {
    count = 1

    network {
      mode = "bridge"
      port "web" { static = 3000 }
      port "api" { static = 8000 }
    }

    ## Baserow Backend API
    task "backend" {
      driver = "docker"
      config {
        image = "baserow/backend:1.34.5"
        ports = ["api"]
        volumes = ["local/media:/baserow/media"]
      }
      env = {
        SECRET_KEY              = var.SECRET_KEY
        BASEROW_JWT_SIGNING_KEY = var.BASEROW_JWT_SIGNING_KEY
        DATABASE_PASSWORD       = var.DATABASE_PASSWORD
        DATABASE_HOST           = var.DATABASE_HOST
        DATABASE_USER           = var.DATABASE_USER
        DATABASE_NAME           = var.DATABASE_NAME
        REDIS_PASSWORD          = var.REDIS_PASSWORD
        REDIS_HOST              = var.REDIS_HOST
        REDIS_PORT              = tostring(var.REDIS_PORT)
        BASEROW_PUBLIC_URL      = var.BASEROW_PUBLIC_URL
      }
      service {
        name = "cdh-baserow-backend"
        port = "api"
        check {
          type     = "http"
          path     = "/healthz"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }

    ## Web Frontend
    task "web-frontend" {
      driver = "docker"
      config {
        image = "baserow/web-frontend:1.34.5"
        ports = ["web"]
      }
      env = {
        BASEROW_PUBLIC_URL  = var.BASEROW_PUBLIC_URL
        PRIVATE_BACKEND_URL = var.PRIVATE_BACKEND_URL
      }
      service {
        name = "cdh-baserow-web"
        port = "web"
        check {
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }

    ## Celery Worker
    task "celery-worker" {
      driver = "docker"
      config {
        image   = "baserow/backend:1.34.5"
        command = ["celery-worker"]
        volumes = ["local/media:/baserow/media"]
      }
      env = {
        SECRET_KEY              = var.SECRET_KEY
        BASEROW_JWT_SIGNING_KEY = var.BASEROW_JWT_SIGNING_KEY
        DATABASE_PASSWORD       = var.DATABASE_PASSWORD
        DATABASE_HOST           = var.DATABASE_HOST
        DATABASE_USER           = var.DATABASE_USER
        DATABASE_NAME           = var.DATABASE_NAME
        REDIS_PASSWORD          = var.REDIS_PASSWORD
        REDIS_HOST              = var.REDIS_HOST
        REDIS_PORT              = tostring(var.REDIS_PORT)
      }
      healthcheck {
        test     = ["CMD-SHELL", "/baserow/backend/docker/docker-entrypoint.sh celery-worker-healthcheck"]
        interval = "10s"
        timeout  = "2s"
      }
    }

    ## Celery Export Worker
    task "celery-export" {
      driver = "docker"
      config {
        image   = "baserow/backend:1.34.5"
        command = ["celery-exportworker"]
        volumes = ["local/media:/baserow/media"]
      }
      env = {
        SECRET_KEY              = var.SECRET_KEY
        BASEROW_JWT_SIGNING_KEY = var.BASEROW_JWT_SIGNING_KEY
        DATABASE_PASSWORD       = var.DATABASE_PASSWORD
        DATABASE_HOST           = var.DATABASE_HOST
        DATABASE_USER           = var.DATABASE_USER
        DATABASE_NAME           = var.DATABASE_NAME
        REDIS_PASSWORD          = var.REDIS_PASSWORD
        REDIS_HOST              = var.REDIS_HOST
        REDIS_PORT              = tostring(var.REDIS_PORT)
      }
      healthcheck {
        test     = ["CMD-SHELL", "/baserow/backend/docker/docker-entrypoint.sh celery-exportworker-healthcheck"]
        interval = "10s"
        timeout  = "2s"
      }
    }

    ## Celery Beat Scheduler
    task "celery-beat" {
      driver = "docker"
      config {
        image       = "baserow/backend:1.34.5"
        command     = ["celery-beat"]
        stop_signal = "SIGQUIT"
        volumes     = ["local/media:/baserow/media"]
      }
      env = {
        SECRET_KEY              = var.SECRET_KEY
        BASEROW_JWT_SIGNING_KEY = var.BASEROW_JWT_SIGNING_KEY
        DATABASE_PASSWORD       = var.DATABASE_PASSWORD
        DATABASE_HOST           = var.DATABASE_HOST
        DATABASE_USER           = var.DATABASE_USER
        DATABASE_NAME           = var.DATABASE_NAME
        REDIS_PASSWORD          = var.REDIS_PASSWORD
        REDIS_HOST              = var.REDIS_HOST
        REDIS_PORT              = tostring(var.REDIS_PORT)
      }
    }

    ## Fix Media Volume Permissions
    task "volume-permissions-fixer" {
      driver = "docker"
      config {
        image   = "bash:4.4"
        command = ["chown", "9999:9999", "-R", "/baserow/media"]
        volumes = ["local/media:/baserow/media"]
      }
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }
    }
  }
}
