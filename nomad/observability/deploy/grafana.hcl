variable "branch_or_sha" {
  type = string
  default = "main"
}
job "grafana" {
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "staging"

  group "grafana" {
    count = 1

    network {
      port "grafana" {
        to = 3000
      }
      dns {
        servers = ["10.88.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    service {
      port = "grafana"
      check {
        type = "http"
        port = "grafana"
        path = "/"
        interval = "10s"
        timeout = "1s"
      }
    }

    volume "grafana" {
      type = "host"
      read_only = false
      source = "grafana"
    }

    task "grafana" {
      driver = "podman"

      env {
        GF_LOG_LEVEL          = "ERROR"
        GF_LOG_MODE           = "console"
        GF_PATHS_DATA         = "/var/lib/grafana"
        GF_SERVER_DOMAIN      = "grafana-nomad.lib.princeton.edu"
        GF_SERVER_ROOT_URL    = "https://grafana-nomad.lib.princeton.edu"
        GF_AUTH_GITHUB_ENABLED = true
        GF_AUTH_GITHUB_ALLOW_SIGN_UP = true
        GF_AUTH_GITHUB_AUTO_LOGIN = false
        # The team ID below is the systems developers team in pulibrary.
        GF_AUTH_GITHUB_TEAM_IDS = "195225"
        GF_AUTH_GITHUB_ALLOWED_ORGANIZATIONS = "pulibrary"
        GF_AUTH_GITHUB_ROLE_ATTRIBUTE_PATH = "[login=='tpendragon'][0] && 'GrafanaAdmin' || 'Editor'"
        GF_AUTH_GITHUB_ALLOW_ASSIGN_GRAFANA_ADMIN = true
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/grafana" -}}
        GF_AUTH_GITHUB_CLIENT_ID = {{ .GH_CLIENT_ID }}
        GF_AUTH_GITHUB_CLIENT_SECRET = {{ .GH_SECRET }}
        {{- end -}}
        EOF
      }
      user = "root"

      config {
        image = "docker.io/grafana/grafana:11.3.0"
        ports = ["grafana"]
      }
      volume_mount {
        volume = "grafana"
        destination = "/var/lib/grafana"
        read_only = false
      }
      resources {
        cpu    = 2000
        memory = 2000
      }

    }
  }

}
