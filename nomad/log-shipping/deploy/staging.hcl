variable "branch_or_sha" {
  type    = string
  default = "main"
}

job "log-shipping-staging" {
  datacenters = ["dc1"]
  type        = "system"
  node_pool   = "staging"
  priority    = 60

  group "log-shipping" {
    count = 1

    consul {}

    network {
      dns {
        servers = ["172.17.0.1", "128.112.129.209", "8.8.8.8"]
      }
      port "otlp_grpc" {
        static = 4317
      }
      port "otlp_http" {
        static = 4318
      }
    }

    restart {
      attempts = 2
      interval = "30m"
      delay    = "15s"
      mode     = "delay"
    }

    ephemeral_disk {
      size = 300
    }

    task "nomad-forwarder" {
      driver = "docker"

      env {
        VERBOSE = 2
        LOG_TAG = "logging"
        LOG_FILE = "${NOMAD_ALLOC_DIR}/nomad-logs.log"
        NOMAD_ADDR = "http://host.docker.internal:4646"
      }

      identity {
        env = true
        file = true
      }

      config {
        image = "docker.io/sofixa/nomad_follower:latest"
        extra_hosts = ["host.docker.internal:host-gateway"]
      }

      resources {
        cpu    = 100
        memory = 512
      }
    }

    task "alloy" {
      driver = "docker"

      env {
        NODE_NAME = "${node.unique.name}"
      }

      identity {
        env = true
        file = true
      }

      config {
        image = "docker.io/grafana/alloy:latest"
        ports = ["otlp_grpc", "otlp_http"]
        extra_hosts = ["host.docker.internal:host-gateway"]
        args = [
          "run",
          "local/config.alloy",
        ]
      }

      template {
        destination = "local/config.alloy"
        data        = <<EOH
          logging {
              level  = "info"
              format = "logfmt"
          }

          local.file_match "logs" {
              path_targets = [{
                  __address__ = "localhost",
                  __path__    = "{{ env "NOMAD_ALLOC_DIR" }}/nomad-logs.log",
              }]
          }

          loki.source.file "logs" {
              targets                 = local.file_match.logs.targets
              forward_to              = [loki.process.logs.receiver]
              tail_from_end           = true
              on_positions_file_error = "restart_from_end"
          }

          loki.process "logs" {
              forward_to = [
                  loki.write.destination.receiver,
                  otelcol.receiver.loki.bridge.receiver,
              ]

              stage.json {
                  expressions = {
                      alloc_id     = "alloc_id",
                      job_name     = "job_name",
                      node_name    = "node_name",
                      service_name = "service_name",
                      task_name    = "task_name",
                  }
              }

              stage.drop {
                  expression = "\"(Consul Health Check|check_http[^\"]*)\""
                  drop_counter_reason = "health_check"
              }

              stage.regex {
                  source     = "job_name"
                  expression = ".*-(?P<environment>staging|production)$"
              }

              stage.labels {
                  values = {
                      job_name     = null,
                      alloc_id     = null,
                      node_name    = null,
                      service_name = null,
                      task_name    = null,
                      environment  = null,
                  }
              }
          }

          loki.write "destination" {
              endpoint {
                  url = "http://loki.service.consul:3100/loki/api/v1/push"
              }
          }

          otelcol.receiver.loki "bridge" {
              output {
                  logs = [otelcol.processor.transform.resource_attrs.input]
              }
          }

          otelcol.processor.transform "resource_attrs" {
              error_mode = "propagate"

              log_statements {
                  context = "log"
                  statements = [
                      "set(resource.attributes[\"service.name\"], log.attributes[\"job_name\"]) where log.attributes[\"job_name\"] != nil",
                      "set(resource.attributes[\"deployment.environment\"], log.attributes[\"environment\"]) where log.attributes[\"environment\"] != nil",
                      "set(resource.attributes[\"host.name\"], log.attributes[\"node_name\"]) where log.attributes[\"node_name\"] != nil",
                  ]
              }

              output {
                  logs = [otelcol.exporter.otlp.signoz.input]
              }
          }

          prometheus.scrape "nomad_client" {
              targets = [{
                  __address__ = "host.docker.internal:4646",
                  __metrics_path__ = "/v1/metrics",
                  __param_format = "prometheus",
              }]

              bearer_token_file = "/secrets/nomad_token"
              forward_to = [otelcol.receiver.prometheus.bridge.receiver]
              scrape_interval = "60s"
              job_name = "nomad-client"
          }

          prometheus.exporter.self "alloy" { }

          prometheus.scrape "alloy_self" {
              targets  = prometheus.exporter.self.alloy.targets
              forward_to = [otelcol.receiver.prometheus.bridge.receiver]
              scrape_interval = "60s"
              job_name = "alloy"
          }

          prometheus.relabel "trim" {
              forward_to = [otelcol.receiver.prometheus.bridge.receiver]
              rule {
                  source_labels = ["__name__"]
                  regex = "nomad_client_(host|allocs)_(cpu|memory).*|nomad_client_allocations_(running|pending|failed)"
                  action = "keep"
              }
          }

          otelcol.receiver.prometheus "bridge" {
              output {
                  metrics = [otelcol.processor.transform.metric_attrs.input]
              }
          }

          otelcol.processor.transform "metric_attrs" {
              error_mode = "propagate"

              metric_statements {
                  context = "resource"
                  statements = [
                      "set(attributes[\"service.name\"], \"nomad-client\")",
                      "set(attributes[\"host.name\"], \"{{ env "NODE_NAME" }}\")",
                      "set(attributes[\"deployment.environment\"], \"staging\")",
                  ]
              }

              output {
                  metrics = [otelcol.exporter.otlp.signoz.input]
              }
          }

          otelcol.receiver.otlp "default" {
              grpc {
                  endpoint = "0.0.0.0:4317"
              }
              http {
                  endpoint = "0.0.0.0:4318"
              }

              output {
                  traces  = [otelcol.exporter.otlp.signoz.input]
                  metrics = [otelcol.exporter.otlp.signoz.input]
                  logs    = [otelcol.exporter.otlp.signoz.input]
              }
          }

          otelcol.exporter.otlp "signoz" {
              client {
                  endpoint = "k8s-staging1.lib.princeton.edu:32317"
                  tls {
                      insecure = true
                  }
              }
          }
        EOH
      }

      resources {
        cpu    = 100
        memory = 512
      }
    }
  }
}
