variable "branch_or_sha" {
  type    = string
  default = "latest-02-27-2026"
}

job "reservoir" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "sandbox"

  group "reservoir-all" {
    count = 1

    network {
      mode = "host"
      port "http" {
        static = 8081
      }
    }

    service {
      name     = "reservoir-sandbox"
      provider = "consul"
      port     = "http"

      check {
        type     = "http"
        port     = "http"
        path     = "/reservoir"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "reservoir" {
      driver = "podman"

      template {
        data        = file("sandbox.env")
        destination = "secrets/db.env"
        env         = true
        change_mode = "restart"
      }

      config {
        image        = "ghcr.io/pulibrary/reservoir-jit:${var.branch_or_sha}"
        force_pull   = true
        network_mode = "host"
      }

      resources {
        cpu    = 2000
        memory = 2048
      }
    }
  }
}
