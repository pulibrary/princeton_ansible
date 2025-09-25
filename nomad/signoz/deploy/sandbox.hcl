variable "frontend_image"    { type = string default = "signoz/frontend:0.39.0" }
variable "query_image"       { type = string default = "signoz/query-service:0.39.0" }
variable "otelcol_image"     { type = string default = "otel/opentelemetry-collector-contrib:0.111.0" }
variable "clickhouse_image"  { type = string default = "clickhouse/clickhouse-server:24.7" }

job "signoz-sandbox" {
  region      = "global"
  datacenters = ["dc1"]
  node_pool   = "all"
  type        = "service"
  priority    = 50

  group "app" {
    count = 1

    restart { attempts = 3 interval = "30s" delay = "10s" mode = "delay" }

    # dynamic host ports; Consul advertises node IP + port
    network {
      port "ui"        {}   # SigNoz UI (frontend)
      port "otlp_grpc" {}   # OTLP gRPC ingest
      port "otlp_http" {}   # OTLP HTTP ingest
    }

    ephemeral_disk { size = 1024 }

    task "clickhouse" {
      driver = "podman"
      config {
        image   = var.clickhouse_image
        volumes = ["/data/signoz/clickhouse:/var/lib/clickhouse:Z"]
        ulimit  = ["nofile=262144:262144"]
      }
      resources { cpu = 1000 memory = 2048 }
      service {
        name = "signoz-clickhouse"
        check { name="tcp-9000" type="tcp" port=9000 interval="15s" timeout="3s" }
      }
    }

    task "otelcol" {
      driver = "podman"
      config {
        image  = var.otelcol_image
        args   = ["--config=/etc/signoz/otel.yaml"]
        ports  = ["otlp_grpc", "otlp_http"]
        volumes = ["/etc/signoz/otel.yaml:/etc/signoz/otel.yaml:ro,Z"]
      }
      resources { cpu = 300 memory = 384 }
    }

    task "query" {
      driver = "podman"
      config {
        image = var.query_image
      }
      env {
        CLICKHOUSE_ADDR = "tcp://127.0.0.1:9000?database=signoz"
      }
      resources { cpu = 500 memory = 1024 }
      service {
        name = "signoz-query"
        port = 8080
        check { name="http-8080" type="http" path="/health" interval="15s" timeout="3s" }
      }
    }

    task "frontend" {
      driver = "podman"
      config {
        image = var.frontend_image
        ports = ["ui"]
      }
      # If the frontend needs an explicit API URL, we can set it later.
      resources { cpu = 500 memory = 512 }
      service {
        name         = "signoz-ui"
        port         = "ui"
        address_mode = "host"
        check {
          name         = "http-root"
          type         = "http"
          path         = "/"
          interval     = "10s"
          timeout      = "2s"
          address_mode = "host"
        }
      }
    }
  }
}

