# SigNoz deployment without persistent volumes for testing
variable "branch_or_sha" {
  type    = string
  default = "main"
}

job "signoz" {
  region      = "global"
  datacenters = ["dc1"]
  node_pool   = "sandbox"
  type        = "service"
  priority    = 50

  group "signoz" {
    count = 1

    network {
      port "ch" {
        static = 9000
      }
      port "ui" {
        static = 3301
      }
      port "query" {
        static = 8080
      }
      port "otlp_grpc" {
        static = 4317
      }
      port "otlp_http" {
        static = 4318
      }
    }

    # ClickHouse without persistent storage
    task "clickhouse" {
      driver = "podman"

      config {
        image        = "docker.io/clickhouse/clickhouse-server:23.8"
        network_mode = "host"
        # No volume mounts - use container storage
        ulimit       = { nofile= "262144:262144" }
        force_pull   = true
      }

      env {
        CLICKHOUSE_DB       = "signoz"
        CLICKHOUSE_USER     = "default"
        CLICKHOUSE_PASSWORD = ""
      }

      resources {
        cpu    = 1000
        memory = 2048
      }

      service {
        name = "signoz-clickhouse"
        port = "ch"

        check {
          name     = "tcp-9000"
          type     = "tcp"
          interval = "10s"
          timeout  = "3s"
        }
      }
    }

    # OpenTelemetry Collector
    task "otelcol" {
      driver = "podman"

      config {
        image        = "docker.io/otel/opentelemetry-collector-contrib:0.88.0"
        network_mode = "host"
        args         = ["--config=/local/otel.yaml"]
        force_pull   = true
      }

      template {
        data = <<EOF
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

exporters:
  clickhouse:
    endpoint: tcp://127.0.0.1:9000?database=signoz
    timeout: 5s
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 30s
      max_elapsed_time: 300s

processors:
  batch:
    timeout: 10s

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [clickhouse]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [clickhouse]
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [clickhouse]
EOF

        destination = "local/otel.yaml"
      }

      resources {
        cpu    = 1000
        memory = 512
      }

      restart {
        attempts = 10
        interval = "30m"
        delay    = "15s"
        mode     = "delay"
      }
    }

    # Query Service
    task "query" {
      driver = "podman"

      config {
        image        = "docker.io/signoz/query-service:0.44.0"
        force_pull   = true
        network_mode = "host"
        # No volume mounts
      }

      env {
        ClickHouseUrl    = "tcp://127.0.0.1:9000?database=signoz"
        STORAGE          = "clickhouse"
        GODEBUG          = "netdns=go"
        TELEMETRY_ENABLED = "false"
        DEPLOYMENT_TYPE  = "docker-standalone-amd"
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      restart {
        attempts = 10
        interval = "30m"
        delay    = "15s"
        mode     = "delay"
      }

      service {
        name = "signoz-query"
        port = "query"
        
        check {
          name     = "http-8080"
          type     = "http"
          path     = "/api/v1/health"
          interval = "15s"
          timeout  = "3s"
        }
      }
    }

    # Frontend
    task "frontend" {
      driver = "podman"

      config {
        image        = "docker.io/signoz/frontend:0.44.0"
        network_mode = "host"
        force_pull   = true
      }

      env {
        FRONTEND_API_URL = "http://127.0.0.1:8080"
      }

      resources {
        cpu    = 500
        memory = 512
      }

      service {
        name         = "signoz-ui"
        port         = "ui"
        address_mode = "host"

        check {
          name         = "http-health"
          type         = "http"
          path         = "/"
          interval     = "10s"
          timeout      = "3s"
          address_mode = "host"
        }
      }
    }
  }
}