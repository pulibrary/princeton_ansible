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
    }

    # ClickHouse - start first
    task "clickhouse" {
      driver = "podman"

      config {
        image        = "docker.io/clickhouse/clickhouse-server:23.11-alpine"
        network_mode = "host"
        ports        = ["9000", "8123"]
        ulimit       = { 
          nofile = "262144:262144" 
        }
      }

      env {
        CLICKHOUSE_DB       = "signoz"
        CLICKHOUSE_USER     = "default"
        CLICKHOUSE_PASSWORD = ""
        CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT = "1"
      }

      resources {
        cpu    = 2000
        memory = 4096
      }

      service {
        name = "clickhouse"
        port = 9000
        
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
      
      # Ensure ClickHouse starts first
      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      config {
        image        = "docker.io/signoz/query-service:0.44.0"
        network_mode = "host"
        ports        = ["8080", "8085"]
        command      = "signoz-query-service"
        args         = []
      }

      template {
        data = <<EOF
#!/bin/bash
# Wait for ClickHouse to be ready
echo "Waiting for ClickHouse..."
while ! nc -z localhost 9000; do
  sleep 2
done
echo "ClickHouse is ready"

# Run the query service
exec /usr/bin/signoz-query-service
EOF
        destination = "local/start.sh"
        perms       = "755"
      }

      env {
        ClickHouseUrl     = "tcp://localhost:9000/?database=signoz"
        STORAGE           = "clickhouse"
        GODEBUG          = "netdns=go"
        TELEMETRY_ENABLED = "false"
        DEPLOYMENT_TYPE   = "docker-standalone-amd"
        SIGNOZ_LOCAL_DB_PATH = "/var/lib/signoz/signoz.db"
      }

      resources {
        cpu    = 1000
        memory = 1024
      }

      service {
        name = "query-service"
        port = 8080
        
        check {
          type     = "http"
          path     = "/api/v1/version"
          interval = "30s"
          timeout  = "5s"
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
        ports        = ["3301"]
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
        port = 3301
        
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
        ports        = ["4317", "4318"]
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
        port = 4317
        
        check {
          type     = "tcp"
          interval = "30s"
          timeout  = "5s"
        }
      }
    }
  }
}
