variable "branch_or_sha" {
  type    = string
  default = "main"
}

variable "n8n_image_tag" {
  type    = string
  default = "1.64.1"
}

# Public hostname used by NGINX Plus and n8n’s own URLs
variable "public_hostname" {
  type    = string
  default = "nodemation-sandbox.lib.princeton.edu"
}

# Timezone for n8n’s scheduling
variable "generic_timezone" {
  type    = string
  default = "America/New_York"
}

job "nodemation-sandbox" {
  region      = "global"
  datacenters = ["dc1"]
  node_pool   = "all"
  type        = "service"
  priority    = 50

  group "app" {
    count = 1

    restart {
      attempts = 5
      interval = "1m"
      delay    = "5s"
      mode     = "delay"
    }

    # Allocate a web port; we do not force a CNI mode to avoid bridge constraints.
    network {
      port "web" { to = 5678 }
    }

    # Scratch space for logs/tmp
    ephemeral_disk {
      size = 1024 # MB
    }

    task "n8n" {
      driver = "podman"

      config {
        image = "docker.io/n8nio/n8n:${var.n8n_image_tag}"
        ports = ["web"]
        volumes = [
          # Persistent n8n data
          "/srv/nomad/host_volumes/nodemation-sandbox-data:/home/node/.n8n",
          "/srv/nomad/host_volumes/nodemation-sandbox-files:/files"
        ]
      }

      env {
        # Mirror compose settings, but let NGINX Plus terminate TLS
        N8N_HOST        = var.public_hostname
        N8N_PORT        = "5678"
        N8N_PROTOCOL    = "https"
        NODE_ENV        = "production"
        WEBHOOK_URL     = "https://${var.public_hostname}/"
        GENERIC_TIMEZONE = var.generic_timezone

        # basic auth or for break glass:
        N8N_BASIC_AUTH_ACTIVE = "true"
        N8N_BASIC_AUTH_USER   = "admin"
        N8N_BASIC_AUTH_PASSWORD = "change-me"
      }

      resources {
        cpu    = 2000  # ~2 vCPU
        memory = 4096  # 4 GiB
      }

      service {
        # Register for NGINX Plus via Consul DNS
        name         = "nodemation-sandbox"
        port         = "web"
        address_mode = "host"

        check {
          name         = "http-root"
          type         = "http"
          path         = "/"
          interval     = "10s"
          timeout      = "2s"
          header { Host = [var.public_hostname] }
          address_mode = "host"
        }
      }
    }
  }
}

