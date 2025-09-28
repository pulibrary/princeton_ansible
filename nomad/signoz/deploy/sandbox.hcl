# Satisfy the deploy script's -var "branch_or_sha=..."
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

    # Reserve labeled ports
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
    }

    # ClickHouse
    task "clickhouse" {
      driver = "podman"

      config {
        image        = "docker.io/clickhouse/clickhouse-server:24.8"
        network_mode = "host"
        volumes      = ["/data/signoz/clickhouse:/var/lib/clickhouse"]
        ulimit       = { nofile= "262144:262144" }
        force_pull   = true
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
        image        = "docker.io/otel/opentelemetry-collector-contrib:0.120.0"
        network_mode = "host"
        args         = ["--config=/etc/signoz/otel.yaml"]
        volumes      = ["/etc/signoz/otel.yaml:/etc/signoz/otel.yaml:ro"]
        force_pull   = true
      }

      resources {
        cpu    = 1000
        memory = 512
      }
      restart {
        attempts = 10
        interval = "30m"
        delay = "10s"
        mode = "delay"
      }
    }

    task "query" {
      driver = "podman"

      config {
        image        = "docker.io/signoz/query-service:v1.2.0"
        force_pull   = true
        network_mode = "host"
        volumes      = ["/data/signoz/app:/var/lib/signoz"]
      }

      env {
        STORAGE         = "clickhouse"
        CLICKHOUSE_ADDR = "tcp://127.0.0.1:9000?database=signoz"
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      restart {
        attempts = 10
        interval = "30m"
        delay = "10s"
        mode = "delay"
      }

      service {
        name = "signoz-query"
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
        image        = "docker.io/signoz/frontend:v1.2.0"
        network_mode = "host"
        volumes      = ["/etc/signoz/frontend.nginx.conf:/etc/nginx/conf.d/default.conf:ro"]
        force_pull   = true
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