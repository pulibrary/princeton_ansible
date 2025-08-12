variable "branch_or_sha" {
  type    = string
  default = "main"
}

# Pin the Baserow image version.
variable "baserow_image_tag" {
  type    = string
  default = "1.34.5"
}

job "cdh-baserow-staging" {
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

    # Bridge mode so Consul advertises the node IP + mapped host port.
    network {
      mode = "bridge"
      port "http" { to = 80 }  # Caddy listens on 80 inside the container
    }

    task "baserow" {
      driver = "podman"

      config {
        image  = "docker.io/baserow/baserow:${var.baserow_image_tag}"
        ports  = ["http"]

        volumes = [
          "/srv/nomad/host_volumes/cdh-baserow-staging:/baserow/data"
        ]
      }

      env {
        # Public URL (TLS terminated at NGINX Plus).
        BASEROW_PUBLIC_URL = "https://cdh-baserow-staging.lib.princeton.edu"
        # Leave Caddy on default :80; no BASEROW_CADDY_ADDRESSES needed.
      }

      resources {
        cpu    = 1000
        memory = 2048
      }

      service {
        name         = "cdh-baserow-staging"
        port         = "http"

        # Register node IP + mapped port in Consul (not container IP).
        address_mode = "host"

        check {
          name         = "http-root"
          type         = "http"
          path         = "/"
          interval     = "10s"
          timeout      = "2s"
          header { Host = ["cdh-baserow-staging.lib.princeton.edu"] }

          # Health check should also use node IP + mapped port.
          address_mode = "host"
        }
      }
    }
  }
}

