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
        to = "8081"
      }
      port "https" {}
    }

    service {
      port = "http"

      check {
        type = "http"
        port = "http"
        path = "/reservoir/upload-form"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "reservoir" {
      driver = "podman"

      config {
        image = "ghcr.io/pulibrary/reservoir-jit:latest-02-27-2026"
      }

      resources {
        cpu = 2000
        memory = 2048
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
      {{- if nomadVarExists "nomad/jobs/reservoir-sandbox" -}}
      {{- with nomadVar "nomad/jobs/reservoir-sandbox" -}}
      DB_USERNAME={{ .DB_USERNAME }}
      DB_PASSWORD={{ .DB_PASSWORD }}
      DB_DATABASE={{ .DB_DATABASE }}
      DB_HOST={{ .DB_HOST }}
      {{- end -}}
      {{- else -}}
      MISSING_NOMAD_VAR=1
      {{- end -}}
      EOF
      }
    }
  }
}
