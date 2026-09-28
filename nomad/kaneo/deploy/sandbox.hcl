variable "branch_or_sha" {
  type    = string
  default = "main"
}

variable "kaneo_image" {
  type    = string
  default = "ghcr.io/usekaneo/kaneo:latest"
}

job "kaneo-sandbox" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "sandbox"

  group "web" {
    count = 1

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "30s"
      healthy_deadline = "5m"
      auto_revert      = true
    }

    network {
      port "http" { to = 5173 }

      dns {
        servers = ["172.17.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    service {
      name = "kaneo-sandbox"
      port = "http"

      check {
        type     = "http"
        port     = "http"
        path     = "/api/health"
        interval = "10s"
        timeout  = "5s"
      }
    }

    task "kaneo" {
      driver = "docker"

      config {
        image = var.kaneo_image
        ports = ["http"]
      }

      env {
        KANEO_CLIENT_URL = "https://kaneo-sandbox.lib.princeton.edu"
        TRUSTED_PROXIES  = "10.0.0.0/8,127.0.0.0/8,::1/128"
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env         = true
        change_mode = "restart"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/kaneo-sandbox" -}}
        POSTGRES_HOST={{ .POSTGRES_HOST }}
        POSTGRES_PORT={{ .POSTGRES_PORT }}
        POSTGRES_DB={{ .POSTGRES_DB }}
        POSTGRES_USER={{ .POSTGRES_USER }}
        POSTGRES_PASSWORD={{ .POSTGRES_PASSWORD }}
        AUTH_SECRET={{ .AUTH_SECRET }}
        CUSTOM_OAUTH_CLIENT_ID={{ .CUSTOM_OAUTH_CLIENT_ID }}
        CUSTOM_OAUTH_CLIENT_SECRET={{ .CUSTOM_OAUTH_CLIENT_SECRET }}
        CUSTOM_OAUTH_DISCOVERY_URL={{ .CUSTOM_OAUTH_DISCOVERY_URL }}
        CUSTOM_OAUTH_SCOPES={{ .CUSTOM_OAUTH_SCOPES }}
        CUSTOM_OAUTH_LOGOUT_URL={{ .CUSTOM_OAUTH_LOGOUT_URL }}
        {{- end -}}
        EOF
      }

      resources {
        cpu    = 1000
        memory = 1024
      }
    }
  }
}
