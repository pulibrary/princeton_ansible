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
        image        = "docker.io/clickhouse/clickhouse-server:24.7"
        network_mode = "host"
        volumes      = ["/data/signoz/clickhouse:/var/lib/clickhouse"]
        ulimit       = { nofile= "262144:262144" }
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
        image        = "docker.io/otel/opentelemetry-collector-contrib:0.111.0"
        network_mode = "host"
        args         = ["--config=/etc/signoz/otel.yaml"]
        volumes      = ["/etc/signoz/otel.yaml:/etc/signoz/otel.yaml:ro"]
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
    # Wait for ClickHouse to accept connections before starting other tasks
task "wait-ch" {
  driver = "raw_exec"

  lifecycle {
    hook = "prestart"
  }

  config {
    command = "/bin/sh"
    args    = ["-lc", "for i in $(seq 1 60); do nc -z 127.0.0.1 9000 && exit 0; sleep 1; done; echo 'ClickHouse not ready after 60s' >&2; exit 1"]
  }

  resources {
    cpu    = 50
    memory = 32
  }
}

    # SigNoz query service (backend API)
    task "query" {
      driver = "podman"

      config {
        image        = "docker.io/signoz/query-service:0.39.0"
        network_mode = "host"
        volumes      = ["/data/signoz/app:/var/lib/signoz"]
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

        # With host networking, numeric check needs address_mode="driver" + explicit port
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

      restart {
    attempts = 10
    interval = "30m"
    delay    = "10s"
    mode     = "delay"
  }
    }

    # SigNoz frontend (UI)
    task "frontend" {
      driver = "podman"

      config {
        image        = "docker.io/signoz/frontend:0.39.0"
        network_mode = "host"
        volumes      = ["/etc/signoz/frontend.nginx.conf:/etc/nginx/conf.d/default.conf:ro"]
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

