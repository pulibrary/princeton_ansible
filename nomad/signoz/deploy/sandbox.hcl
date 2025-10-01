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
      mode = "host"
      
      # Define port labels for host networking
      port "clickhouse" {
        static = 9000
      }
      port "clickhouse_http" {
        static = 8123
      }
      port "query" {
        static = 8080
      }
      port "query_admin" {
        static = 8085
      }
      port "frontend" {
        static = 3301
      }
      port "otlp_grpc" {
        static = 4317
      }
      port "otlp_http" {
        static = 4318
      }
    }

    # ClickHouse - must start first
    task "clickhouse" {
      driver = "podman"

      config {
        image        = "docker.io/clickhouse/clickhouse-server:23.11-alpine"
        network_mode = "host"
        ports        = ["clickhouse", "clickhouse_http"]
        ulimit = {
          nofile = "262144:262144"
        }
      }

      env {
        CLICKHOUSE_DB                         = "signoz"
        CLICKHOUSE_USER                       = "default"
        CLICKHOUSE_PASSWORD                   = ""
        CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT  = "1"
      }

      resources {
        cpu    = 2000
        memory = 4096
      }

      service {
        name = "clickhouse"
        port = "clickhouse"

        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }

    # Query Service - waits for ClickHouse
    task "query-service" {
      driver = "podman"

      config {
        image        = "docker.io/signoz/query-service:0.44.0"
        network_mode = "host"
        ports        = ["query", "query_admin"]
        volumes      = ["${NOMAD_ALLOC_DIR}/signoz:/var/lib/signoz"]
        command      = "/bin/bash"
        args         = ["-c", "while ! nc -z localhost 9000; do echo 'Waiting for ClickHouse...'; sleep 2; done; echo 'ClickHouse ready'; exec /usr/bin/signoz-query-service"]
      }

      env {
        ClickHouseUrl        = "tcp://localhost:9000/?database=signoz"
        STORAGE              = "clickhouse"
        GODEBUG              = "netdns=go"
        TELEMETRY_ENABLED    = "false"
        DEPLOYMENT_TYPE      = "docker-standalone-amd"
        SIGNOZ_LOCAL_DB_PATH = "/var/lib/signoz/signoz.db"
      }

      resources {
        cpu    = 1000
        memory = 1024
      }

      service {
        name = "query-service"
        port = "query"

        check {
          type     = "http"
          path     = "/api/v1/version"
          interval = "30s"
          timeout  = "5s"
        }
      }
    }

    # Frontend - just wait with sleep
    task "frontend" {
      driver = "podman"

      config {
        image        = "docker.io/signoz/frontend:0.44.0"
        network_mode = "host"
        ports        = ["frontend"]
        # Don't override the default entrypoint, let nginx start normally
      }

      env {
        FRONTEND_API_URL = "http://localhost:8080"
      }

      resources {
        cpu    = 500
        memory = 512
      }

      # Add a restart policy to handle initial failures
      restart {
        attempts = 5
        delay    = "30s"
        interval = "5m"
        mode     = "delay"
      }

      service {
        name = "signoz-frontend"
        port = "frontend"

        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "5s"
        }
      }
    }

    # OpenTelemetry Collector
    task "otel-collector" {
      driver = "podman"

      config {
        image        = "docker.io/signoz/signoz-otel-collector:0.88.11"
        network_mode = "host"
        ports        = ["otlp_grpc", "otlp_http"]
        command      = "/otelcol-contrib"
        args         = ["--config=/local/otel-config.yaml"]
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

processors:
  batch:
    send_batch_size: 10000
    timeout: 10s

exporters:
  clickhousetraces:
    datasource: tcp://localhost:9000/?database=signoz
    timeout: 10s

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [clickhousetraces]
EOF
        destination = "local/otel-config.yaml"
      }

      env {
        GOGC = "80"
      }

      resources {
        cpu    = 1000
        memory = 1024
      }

      service {
        name = "otel-collector"
        port = "otlp_grpc"

        check {
          type     = "tcp"
          interval = "30s"
          timeout  = "5s"
        }
      }
    }
  }
}
