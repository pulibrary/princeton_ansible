# Prometheus is a metrics aggregator. This configuration automatically pulls all
# metrics from services registered in Consul with the tag "metrics".
variable "branch_or_sha" {
  type = string
  default = "main"
}
job "prometheus" {
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "staging"

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
      password: '{{with nomadVar "nomad/jobs/prometheus"}}{{ .METRICS_BASIC_PASSWORD }}{{end}}'
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
        credentials: '{{with nomadVar "nomad/jobs/prometheus"}}{{ .CONSUL_ACL_TOKEN }}{{end}}'
    relabel_configs:
    - source_labels: ['__meta_consul_tags']
      regex: '(.*)http(.*)'
      action: keep
  - job_name: 'nomad_metrics'
    scrape_interval: 5s
    authorization:
      credentials: '{{with nomadVar "nomad/jobs/prometheus"}}{{ .METRICS_AUTH_TOKEN }}{{end}}'
    consul_sd_configs:
    - server: '{{ env "NOMAD_IP_prometheus_ui" }}:8500'
      authorization:
        credentials: '{{with nomadVar "nomad/jobs/prometheus"}}{{ .CONSUL_ACL_TOKEN }}{{end}}'

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
