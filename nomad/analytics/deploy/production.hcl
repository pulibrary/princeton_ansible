variable "branch_or_sha" {
  type = string
  default = "main"
}

job "analytics-production" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  node_pool = "production"

  group "web" {
    count = 2

    update {
      canary = 1
      auto_promote = true
      auto_revert = true
    }

    network {
      port "http" { to = 3000 }

      dns {
        servers = ["10.88.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    service {
      tags = ["live"]
      canary_tags = ["canary"]
      port = "http"

      check {
        type = "http"
        port = "http"
        path = "/api/heartbeat"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "app" {
      driver = "docker"

      user = "1001:1001"

      config {
        image        = "ghcr.io/umami-software/umami:3.2.0"
        ports = ["http"]
        # Don't allow writing anything to the file system.
        readonly_rootfs = true
        # We don't need any CAP privileges - don't allow any privilege escalation.
        cap_drop = ["ALL"]
        security_opt = [
          "no-new-privileges"
        ]
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/analytics-production" -}}
        DATABASE_TYPE = 'postgresql'
        APP_SECRET = '{{ .SECRET_KEY_BASE }}'
        DATABASE_URL = 'postgresql://{{ .DB_USER }}:{{ .DB_PASSWORD }}@{{ .POSTGRES_HOST }}:5432/{{ .DB_NAME }}'
        {{- end -}}
        EOF
      }

      resources {
        cpu    = 1000
        memory = 2048
      }
    }
  }
}
