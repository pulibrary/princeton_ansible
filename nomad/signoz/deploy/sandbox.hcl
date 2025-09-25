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

    restart {
      attempts = 3
      interval = "30s"
      delay    = "10s"
      mode     = "delay"
    }

    # Use dynamic host ports; register with node IP
    network {
      port "ui"         {} # SigNoz UI
      port "otlp_grpc"  {} # OTLP gRPC ingest
      port "otlp_http"  {} # OTLP HTTP ingest
      # clickhouse is internal; no host port needed
    }

    ephemeral_disk { size = 1024 } # scratch/logs

    task "clickhouse" {
      driver = "podman"
      config {
        image   = var.clickhouse_image
        volumes = [
          "/data/signoz/clickhouse:/var/lib/clickhouse:Z"
        ]
        ulimit = ["nofile=262144:262144"]
        # no "ports" -> stays internal on bridge
      }
      resources { cpu = 1000 memory = 2048 }
      service {
        name = "signoz-clickhouse"
        # no port registration -> internal only
        check {
          name     = "tcp-9000"
          type     = "tcp"
          port     = 9000
          interval = "15s"
          timeout  = "3s"
        }
      }
    }

    task "otelcol" {
      driver = "podman"
      config {
        image  = var.otelcol_image
        args   = ["--config=/etc/signoz/otel.yaml"]
        ports  = ["otlp_grpc", "otlp_http"]
        volumes = [
          "/etc/signoz/otel.yaml:/etc/signoz/otel.yaml:ro,Z"
        ]
      }
      resources { cpu = 300 memory = 384 }
    }

    task "query" {
      driver = "podman"
      config {
        image = var.query_image
        # internal service; no host port
      }
      env {
        CLICKHOUSE_ADDR = "tcp://127.0.0.1:9000?database=signoz"
        # OIDC (kept same names you were using)
        GOOGLE_OAUTH_CLIENT_ID     = "{{ vault_signoz_google_oidc_client_id }}"
        GOOGLE_OAUTH_CLIENT_SECRET = "{{ vault_signoz_google_oidc_client_secret }}"
        GOOGLE_OAUTH_REDIRECT_URL  = "https://sandbox-signoz.lib.princeton.edu/api/v1/complete/google"
      }
      resources { cpu = 500 memory = 1024 }
      service {
        name = "signoz-query"
        port = 8080
        check {
          name     = "http-8080"
          type     = "http"
          path     = "/health"
          interval = "15s"
          timeout  = "3s"
        }
      }
    }

    task "frontend" {
      driver = "podman"
      config {
        image = var.frontend_image
        ports = ["ui"]
      }
      env {
        # Frontend calls query service on the node via Consul
        # (optionally: SIG_NOZ_QUERY_URL = "http://signoz-query.service.consul:8080")
      }
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
