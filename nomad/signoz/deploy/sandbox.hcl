job "signoz" {
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "sandbox"
  priority    = 50

  group "signoz" {
    count = 1

    # Reserve labeled ports so services/checks can reference labels, not numbers
    network {
      port "ch" {
        static = 9000
      }
      port "ui" {
        static = 3301
      }
      port "otlp_grpc" {
        static = 4317
      }
      port "otlp_http" {
        static = 4318
      }
      constraint {
        attribute = "${node.unique.name}"
        value     = "sandbox-signoz1"
      }
    }

    # ClickHouse
    task "clickhouse" {
      driver = "podman"

      config {
        image        = "clickhouse/clickhouse-server:24.7"
        network_mode = "host"
        volumes      = ["/data/signoz/clickhouse:/var/lib/clickhouse:Z"]
        ulimit       = ["nofile=262144:262144"]
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
        image        = "otel/opentelemetry-collector-contrib:0.111.0"
        network_mode = "host"
        args         = ["--config=/etc/signoz/otel.yaml"]
        volumes      = ["/etc/signoz/otel.yaml:/etc/signoz/otel.yaml:ro,Z"]
      }

      resources {
        cpu    = 300
        memory = 384
      }
    }

    # SigNoz query service (backend API)
    task "query" {
      driver = "podman"

      config {
        image        = "signoz/query-service:0.39.0"
        network_mode = "host"
      }

      env {
        CLICKHOUSE_ADDR = "tcp://127.0.0.1:9000?database=signoz"
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      service {
        name = "signoz-query"
        # the service listens on 8080 internally; with host net, checks can be numeric
        check {
          name         = "http-8080"
          type         = "http"
          path         = "/health"
          interval     = "15s"
          timeout      = "3s"
          address_mode = "driver"
          port         = 8080
        }
      }
    }

    # SigNoz frontend (UI)
    task "frontend" {
      driver = "podman"

      config {
        image        = "signoz/frontend:0.39.0"
        network_mode = "host"
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
          name         = "http-root"
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

