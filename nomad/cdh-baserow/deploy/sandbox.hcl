variable "branch_or_sha" {
  type    = string
  default = "main"
}

variable "baserow_image_tag" {
  type    = string
  default = "1.34.5"
}

job "cdh-baserow-sandbox" {
  region      = "global"
  datacenters = ["dc1"]
  node_pool   = "all"
  type        = "service"
  priority    = 50

  group "app" {
    count = 1

    restart {
      attempts = 3
      interval = "30s"
      delay    = "10s"
      mode     = "delay"
    }

    network {
      # Internal HTTP only; NGINX Plus terminates TLS.
      port "http" {
        to = 80
      }
    }

    task "baserow" {
      driver = "podman"

      config {
        image  = "docker.io/baserow/baserow:${var.baserow_image_tag}"
        ports  = ["http"]

        volumes = [
          "/srv/nomad/baserow/cdh-baserow-sandbox:/baserow/data"
        ]
      }

      env {
        # Must be the public URL users hit (TLS ends at NGINX Plus).
        BASEROW_PUBLIC_URL = "https://cdh-baserow-sandbox.lib.princeton.edu"
        # Leave Caddy on its default :80 (no BASEROW_CADDY_ADDRESSES).
      }

      resources {
        cpu    = 1000
        memory = 2048
      }

      service {
        name = "cdh-baserow-sandbox"
        port = "http"

        check {
          name     = "http-root"
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
          header { Host = ["cdh-baserow-sandbox.lib.princeton.edu"] }
        }
      }
    }
  }
}

