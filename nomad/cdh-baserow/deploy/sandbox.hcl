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

    # No explicit CNI mode to avoid bridge version constraints
    network {
      port "http" { to = 80 }  # Caddy listens on 80 inside the container
    }

    # Give the alloc some scratch space for logs/tmp
    ephemeral_disk {
      size = 1024  # MB
    }

    task "baserow" {
      driver = "podman"

      config {
        image  = "docker.io/baserow/baserow:${var.baserow_image_tag}"
        ports  = ["http"]

        volumes = [
          "/srv/nomad/host_volumes/cdh-baserow-sandbox:/baserow/data"
        ]
      }

      env {
        BASEROW_PUBLIC_URL = "https://cdh-baserow-sandbox.lib.princeton.edu"
        # Caddy stays on :80 (no BASEROW_CADDY_ADDRESSES needed)
      }

      resources {
        cpu    = 2000   # 2 vCPU
        memory = 4096   # 4 GiB
      }

      service {
        name         = "cdh-baserow-sandbox"
        port         = "http"

        # Register node IP + mapped host port in Consul
        address_mode = "host"

        check {
          name         = "http-root"
          type         = "http"
          path         = "/"
          interval     = "10s"
          timeout      = "2s"
          header { Host = ["cdh-baserow-sandbox.lib.princeton.edu"] }
          address_mode = "host"
        }
      }
    }
  }
}
