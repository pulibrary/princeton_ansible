variable "branch_or_sha" {
  type    = string
  default = "main"
}


job "reservoir" {
  region = "global"
  datacenters = ["dc1"]
  type = "service"
  node_pool = "sandbox"

  group "reservoir-all" {
    count = 1

    network {
      port "http" {
        to = 8081
      }
      port "https" {}
    }

    service {
      port = "http"

      check {
        type = "http"
        port = "http"
        path = "/reservoir"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "reservoir" {
      driver = "podman"

      env {
        DB_USERNAME= "reservoir_db_user"
        DB_PASSWORD= "reservoir_db_password"
        DB_DATABASE= "reservoir_db"
        DB_HOST= "lib-postgres-staging1.princeton.edu"
      }

      config {
        image = "ghcr.io/pulibrary/reservoir-jit:latest-02-27-2026"
        force_pull = true
      }

      resources {
        cpu = 2000
        memory = 2048
      }

    }
  }
}
