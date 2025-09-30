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

      # Define labeled ports (static since we're using host networking)
      port "ch_tcp"     { static = 9000 }
      port "ch_http"    { static = 8123 }

      port "qs_http"    { static = 8080 }
      port "qs_admin"   { static = 8085 }

      port "fe_http"    { static = 3301 }

      port "otlp_grpc"  { static = 4317 }
      port "otlp_http"  { static = 4318 }
    }

    # ClickHouse - start first
    task "clickhouse" {
      driver = "podman"

      config {
        image        = "docker.io/clickhouse/clickhouse-server:23.11-alpine"
        network_mode = "host"
        # Reference the port LABELS, not numbers
        ports        = ["ch_tcp", "ch_http"]
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
        port = "ch_tcp"  # label!

        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }

    # Query Service - needs ClickHouse to be up
    task "query-service" {
      driver = "podman"

      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      config {
        image        = "docker.io/signoz/query-service:0.44.0"
        network_mode = "host"
        ports        = ["qs_http", "qs_admin"]
        # run the start script we render into /local
        command      = "/bin/sh"
        args         = ["/local/start.sh"]
      }

      template {
        data = <<EOF
#!/bin/sh
# Wait for ClickHouse to be ready
echo "Waiting for ClickHouse on localhost:9000..."
while ! nc -z localhost 9000; do
  sleep 2
done
echo "ClickHouse is ready"

# Run the query service
exec /usr/bin/signoz-query-service
EOF
        destination = "local/start.sh"
        perms       = "0755"
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
        port = "qs_http"

        check {
          type     = "http"
          path     = "/api/v1/version"
          interval = "30s"
          timeout  = "5s"
          # address_mode default is fine since we’re using a labeled port
        }
      }
    }

    # Frontend - needs query service
    task "frontend" {
      driver = "podman"

      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      config {
        image        = "docker.io/signoz/frontend:0.44.0"
        network_mode = "host"
        ports        = ["fe_http"]
        # mount our nginx override into the container
        volumes      = ["local/default.conf:/etc/nginx/conf.d/default.conf"]
      }

      template {
        data = <<EOF
# nginx config override to use localhost
server {
    listen 3301;

    location / {
        root /usr/share/nginx/html;
        try_files $uri /index.html;
    }

    location /api {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF
        destination = "local/default.conf"
        perms       = "0644"
      }

      env {
        FRONTEND_API_URL = "http://localhost:8080"
      }

      resources {
        cpu    = 500
        memory = 512
      }

      service {
        name = "signoz-frontend"
        port = "fe_http"

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

      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      config {
        image        = "docker.io/signoz/signoz-otel-collector:0.88.11"
        network_mode = "host"
        ports        = ["otlp_grpc", "otlp_http"]
        volumes      = ["local/otel-config.yaml:/etc/otel-collector/config.yaml"]
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
        perms       = "0644"
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

