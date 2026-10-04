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
        servers = ["172.17.0.1"]
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
      driver = "docker"

      # Nomad generates a workload JWT with the audience for Entra auth. Then the Entra app trusts Nomad, and boom no rotating secrets in Entra.
      # The identity is only valid for 15 minutes and auto rotates.
      identity {
        name = "entra"
        aud  = ["api://AzureADTokenExchange"]
        file = true
        ttl  = "15m"
      }

      env {
        GF_LOG_LEVEL          = "ERROR"
        GF_LOG_MODE           = "console"
        GF_PATHS_DATA         = "/var/lib/grafana"
        GF_SERVER_DOMAIN      = "grafana-nomad.lib.princeton.edu"
        GF_SERVER_ROOT_URL    = "https://grafana-nomad.lib.princeton.edu"
        # Auth via EntraID. The app is set up so the GrafanaAdmin role has the library devops team as admins, and the library devops users as viewers.
        GF_AUTH_AZUREAD_ENABLED = true
        GF_AUTH_AZUREAD_NAME = "Princeton"
        GF_AUTH_AZUREAD_ALLOW_SIGN_UP = true
        GF_AUTH_AZUREAD_AUTO_LOGIN = true
        # Only allow login w/ Entra. Turn these off if everything explodes.
        GF_AUTH_DISABLE_LOGIN_FORM = true
        GF_AUTH_BASIC_ENABLED = false
        GF_AUTH_AZUREAD_CLIENT_ID = "37a12f8b-d40a-46e2-96c8-963227d25ad4"
        GF_AUTH_AZUREAD_SCOPES = "openid email profile"
        GF_AUTH_AZUREAD_AUTH_URL = "https://login.microsoftonline.com/2ff60116-7431-425d-b5af-077d7791bda4/oauth2/v2.0/authorize"
        GF_AUTH_AZUREAD_TOKEN_URL = "https://login.microsoftonline.com/2ff60116-7431-425d-b5af-077d7791bda4/oauth2/v2.0/token"
        GF_AUTH_AZUREAD_ALLOWED_ORGANIZATIONS = "2ff60116-7431-425d-b5af-077d7791bda4"
        GF_AUTH_AZUREAD_CLIENT_AUTHENTICATION = "workload_identity"
        GF_AUTH_AZUREAD_WORKLOAD_IDENTITY_TOKEN_FILE = "/secrets/nomad_entra.jwt"
        GF_AUTH_AZUREAD_FEDERATED_CREDENTIAL_AUDIENCE = "api://AzureADTokenExchange"
        # If they don't have a role assigned, don't let 'em log in.
        GF_AUTH_AZUREAD_ROLE_ATTRIBUTE_STRICT = true
        GF_AUTH_AZUREAD_ALLOW_ASSIGN_GRAFANA_ADMIN = true
        # Links accounts created by the old GitHub login to Entra by email.
        # We can delete this once everyone has logged in via Entra.
        GF_AUTH_OAUTH_ALLOW_INSECURE_EMAIL_LOOKUP = true
        # Database configuration
        GF_DATABASE_TYPE = "postgres"
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/grafana-staging/grafana" -}}
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
        image = "docker.io/grafana/grafana:13.2.3"
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
        servers = ["172.17.0.1"]
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

    consul {}

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
      target_label: exported_job
    - source_labels: ['__meta_consul_service']
      regex: '.*(staging|production).*'
      replacement: '$${1}'
      target_label: env
    params:
      format: ['prometheus']
EOH
      }

      driver = "docker"

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
