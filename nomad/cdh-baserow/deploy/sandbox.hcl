# Passed by deploy script; unused but for consistency.
variable "branch_or_sha" {
  type    = string
  default = "main"
}

# Pin the Baserow image version.
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
      # Expose an internal HTTP port; map to container port 80.
      port "http" {
        to = 80
      }
    }

    task "baserow" {
      driver = "podman"

      config {
        image = "docker.io/baserow/baserow:${var.baserow_image_tag}"
        ports = ["http"]

        volumes = [
          "/srv/nomad/baserow/cdh-baserow-sandbox:/baserow/data"
        ]
      }

      env {
        # Must match the public URL (TLS is terminated at NGINX Plus).
        BASEROW_PUBLIC_URL = "https://cdh-baserow-sandbox.lib.princeton.edu"
      }

      resources {
        cpu    = 1000   # ~1 vCPU
        memory = 2048   # 2 GiB
      }

      service {
        # Must match the NGINX Plus upstream name.
        name = "cdh-baserow-sandbox"
        port = "http"

        # Health check hitting "/" (what your Consul check was using).
        check {
          name     = "http-root"
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
          # Make Host header match the public hostname.
          header { Host = ["cdh-baserow-sandbox.lib.princeton.edu"] }
        }
      }
    }
  }
}
