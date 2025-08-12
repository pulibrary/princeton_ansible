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
      # Internal HTTP only; NGINX Plus terminates TLS
      port "http" { to = 8080 }
    }

    task "baserow" {
      driver = "podman"

      config {
        image = "docker.io/baserow/baserow:${var.baserow_image_tag}"
        ports = ["http"]

        volumes = [
          "/srv/nomad/host_volumes/cdh-baserow-sandbox:/baserow/data"
        ]

        network_mode = "bridge"
      }

      env {
        BASEROW_PUBLIC_URL      = "https://cdh-baserow-sandbox.lib.princeton.edu"
        BASEROW_CADDY_ADDRESSES = ":8080"
      }

      resources {
        cpu    = 1000
        memory = 2048
      }

      service {
        name = "cdh-baserow-sandbox"
        port = "http"

        check {
          name     = "baserow-health"
          type     = "http"
          path     = "/api/_health/"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}

