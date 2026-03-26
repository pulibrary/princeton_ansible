variable "branch_or_sha" {
  type = string
  default = "main"
}
job "grafana-staging" {
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
      name = "grafana-grafana"
      port = "grafana"
      check {
        type = "http"
        port = "grafana"
        path = "/"
        interval = "10s"
        timeout = "1s"
      }
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
        # Database configuration
        GF_DATABASE_TYPE = "postgres"
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/grafana-staging/grafana" -}}
        GF_AUTH_GITHUB_CLIENT_ID = {{ .GH_CLIENT_ID }}
        GF_AUTH_GITHUB_CLIENT_SECRET = {{ .GH_SECRET }}
        GF_DATABASE_HOST = {{ .DB_HOST }}
        GF_DATABASE_NAME = {{ .DB_NAME }}
        GF_DATABASE_USER = {{ .DB_USER }}
        GF_DATABASE_PASSWORD = {{ .DB_PASSWORD }}
        {{- end -}}
        EOF
      }
      template {
        destination = "local/provisioning/datasources/prometheus.yaml"
        change_mode = "restart"
        data = <<EOF
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus.service.consul:9090
    isDefault: true
    editable: true
EOF
      }

      config {
        image = "docker.io/grafana/grafana:11.3.0"
        ports = ["grafana"]
        volumes = [
          "local/provisioning/datasources/prometheus.yaml:/etc/grafana/provisioning/datasources/prometheus.yaml"
        ]
      }
      resources {
        cpu    = 2000
        memory = 2000
      }

    }
  }

  group "monitoring" {
    count = 1

    network {
      port "prometheus_ui" {
        static = 9090
      }
      dns {
        servers = ["10.88.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    restart {
      attempts = 2
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }

    volume "prometheus" {
      type      = "host"
      read_only = false
      source    = "prometheus"
    }

    service {
      name = "prometheus"
      port = "prometheus_ui"
      check {
        name     = "prometheus_ui port alive"
          type     = "http"
          path     = "/-/healthy"
          interval = "10s"
          timeout  = "2s"
      }
    }

    task "prometheus" {
      user = "9090:9090"
      volume_mount {
        volume      = "prometheus"
        destination = "/prometheus"
        read_only   = false
      }
      template {
        change_mode = "restart"
        destination = "local/prometheus.yml"
        data = <<EOH
---
global:
  scrape_interval:     5s
  evaluation_interval: 5s

scrape_configs:
  - job_name: 'node'
    scrape_interval: 5s
    basic_auth:
      username: metrics_user
      password: '{{with nomadVar "nomad/jobs/grafana-staging/monitoring"}}{{ .METRICS_BASIC_PASSWORD }}{{end}}'
    static_configs:
      - targets:
        - figgy-web-staging1.princeton.edu:9100
        - figgy-web-staging2.princeton.edu:9100
        labels:
          env: staging
          service: figgy
      - targets:
        - dpul-staging3.princeton.edu:9100
        - dpul-staging4.princeton.edu:9100
        labels:
          env: staging
          service: dpul
  - job_name: 'nomad_server_metrics'
    scrape_interval: 5s
    metrics_path: /v1/metrics
    params:
      format: ['prometheus']
    consul_sd_configs:
    - server: '{{ env "NOMAD_IP_prometheus_ui" }}:8500'
      services: ['nomad-clients', 'nomad-servers']
      authorization:
        credentials: '{{with nomadVar "nomad/jobs/grafana-staging/monitoring"}}{{ .CONSUL_ACL_TOKEN }}{{end}}'
    relabel_configs:
    - source_labels: ['__meta_consul_tags']
      regex: '(.*)http(.*)'
      action: keep
  - job_name: 'nomad_metrics'
    scrape_interval: 5s
    authorization:
      credentials: '{{with nomadVar "nomad/jobs/grafana-staging/monitoring"}}{{ .METRICS_AUTH_TOKEN }}{{end}}'
    consul_sd_configs:
    - server: '{{ env "NOMAD_IP_prometheus_ui" }}:8500'
      authorization:
        credentials: '{{with nomadVar "nomad/jobs/grafana-staging/monitoring"}}{{ .CONSUL_ACL_TOKEN }}{{end}}'

    relabel_configs:
    - source_labels: ['__meta_consul_tags']
      regex: '(.*)metrics(.*)'
      action: keep
    - source_labels: ['__meta_consul_service']
      target_label: instance
    - source_labels: ['__meta_consul_service']
      regex: '.*(staging|production).*'
      replacement: '$${1}'
      target_label: env
    params:
      format: ['prometheus']
EOH
      }

      driver = "podman"

      config {
        image = "docker.io/prom/prometheus:v3.2.0"

        volumes = [
          "local/prometheus.yml:/etc/prometheus/prometheus.yml",
        ]

        ports = ["prometheus_ui"]
      }

    }
  }
}
