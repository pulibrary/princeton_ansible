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
        ulimit       = { nofile= "262144:262144" }
        force_pull   = true
      }

      env {
        CLICKHOUSE_DB       = "signoz"
        CLICKHOUSE_USER     = "default"
        CLICKHOUSE_PASSWORD = ""
        CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT = "1"
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

    # Initialize ClickHouse schema
    task "clickhouse-init" {
      driver = "podman"
      
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        image        = "docker.io/signoz/query-service:0.44.0"
        network_mode = "host"
        command      = "/bin/sh"
        args         = ["-c", "sleep 30 && /usr/bin/signoz-query-service --skip-server-run"]
      }

      env {
        ClickHouseUrl    = "tcp://127.0.0.1:9000?database=signoz"
        STORAGE          = "clickhouse"
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    # Query Service
    task "query" {
      driver = "podman"

      config {
        image        = "docker.io/signoz/query-service:0.44.0"
        force_pull   = true
        network_mode = "host"
        # Mount a temporary directory for SQLite database
        volumes      = [
          "local/signoz:/var/lib/signoz"
        ]
      }

      # Create directory for SQLite database
      template {
        data = ""
        destination = "local/signoz/.keep"
      }

      env {
        ClickHouseUrl    = "tcp://127.0.0.1:9000?database=signoz"
        STORAGE          = "clickhouse"
        GODEBUG          = "netdns=go"
        TELEMETRY_ENABLED = "false"
        DEPLOYMENT_TYPE  = "docker-standalone-amd"
        # SQLite database path
        SIGNOZ_LOCAL_DB_PATH = "/var/lib/signoz/signoz.db"
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      restart {
        attempts = 10
        interval = "30m"
        delay    = "30s"  # Give ClickHouse time to start
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

    # OpenTelemetry Collector
    task "otelcol" {
      driver = "podman"

      config {
        image        = "docker.io/signoz/signoz-otel-collector:0.88.11"  # Use SigNoz's collector
        network_mode = "host"
        args         = ["--config=/etc/otel/config.yaml"]
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

processors:
  batch:
    send_batch_size: 10000
    timeout: 10s
  
  signozspanmetrics/prometheus:
    metrics_exporter: prometheus
    latency_histogram_buckets: [100us, 1ms, 2ms, 6ms, 10ms, 50ms, 100ms, 250ms, 500ms, 1000ms, 1400ms, 2000ms, 5s, 10s, 20s, 40s, 60s]
    dimensions_cache_size: 10000

exporters:
  clickhousetraces:
    datasource: tcp://127.0.0.1:9000?database=signoz
    docker_multi_node_cluster: false
    low_cardinal_exception_grouping: false
    low_cardinal_exception_fingerprinting: false
    timeout: 5s
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 30s
      max_elapsed_time: 300s
  
  prometheus:
    endpoint: "0.0.0.0:8889"

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [signozspanmetrics/prometheus, batch]
      exporters: [clickhousetraces]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [prometheus]
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: []
EOF

        destination = "etc/otel/config.yaml"
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
