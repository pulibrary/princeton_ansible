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

    # ClickHouse - using 24.8 for better stability
    task "clickhouse" {
      driver = "podman"
      
      # Start first
      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      config {
        image        = "docker.io/clickhouse/clickhouse-server:24.8"
        network_mode = "host"
        volumes      = [
          "/data/signoz/clickhouse:/var/lib/clickhouse",
          "/data/signoz/clickhouse-logs:/var/log/clickhouse-server"
        ]
        ulimit       = { 
          nofile = "262144:262144",
          nproc  = "65536:65536"
        }
        force_pull   = true
      }

      # Add environment variables for ClickHouse
      env {
        CLICKHOUSE_DB                = "signoz"
        CLICKHOUSE_USER              = "default"
        CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT = "1"
        CLICKHOUSE_PASSWORD          = ""
      }

      resources {
        cpu    = 2000
        memory = 4096
      }

      service {
        name = "signoz-clickhouse"
        port = "ch"

        check {
          name     = "tcp-9000"
          type     = "tcp"
          interval = "10s"
          timeout  = "5s"
          
          check_restart {
            limit = 3
            grace = "90s"
          }
        }
      }
    }

    # Initialize ClickHouse database
    task "clickhouse-init" {
      driver = "podman"
      
      lifecycle {
        hook = "poststart"
      }

      config {
        image        = "docker.io/clickhouse/clickhouse-server:24.8"
        network_mode = "host"
        command      = "clickhouse-client"
        args         = [
          "--host", "127.0.0.1",
          "--query", "CREATE DATABASE IF NOT EXISTS signoz"
        ]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }

    # OpenTelemetry Collector with embedded config
    task "otelcol" {
      driver = "podman"

      config {
        image        = "docker.io/signoz/signoz-otel-collector:0.88.11"
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
    timeout: 10s
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 30s
      max_elapsed_time: 300s
  logging:
    verbosity: normal

processors:
  batch:
    timeout: 10s
  memory_limiter:
    check_interval: 1s
    limit_mib: 400
    spike_limit_mib: 100

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [clickhouse, logging]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [clickhouse]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [clickhouse]
  telemetry:
    logs:
      level: debug
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
        delay    = "30s"
        mode     = "delay"
      }
      
      service {
        name = "signoz-otelcol"
        port = "otlp_grpc"

        check {
          name     = "tcp-4317"
          type     = "tcp"
          interval = "10s"
          timeout  = "3s"
        }
      }
    }

    # Query Service
    task "query" {
      driver = "podman"

      config {
        image        = "docker.io/signoz/query-service:0.44.0"
        force_pull   = true
        network_mode = "host"
        volumes      = ["/data/signoz/signoz:/var/lib/signoz"]
      }

      env {
        ClickHouseUrl    = "tcp://127.0.0.1:9000?database=signoz"
        STORAGE          = "clickhouse"
        GODEBUG          = "netdns=go"
        TELEMETRY_ENABLED = "false"
        DEPLOYMENT_TYPE  = "docker-standalone-amd"
      }

      resources {
        cpu    = 1000
        memory = 1024
      }

      restart {
        attempts = 10
        interval = "30m"
        delay    = "30s"
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
          timeout  = "5s"
          
          check_restart {
            limit = 3
            grace = "120s"
          }
        }
      }
    }

    # SigNoz frontend (UI)
    task "frontend" {
      driver = "podman"

      config {
        image        = "docker.io/signoz/frontend:0.44.0"
        network_mode = "host"
        force_pull   = true
        volumes      = ["local/nginx.conf:/etc/nginx/conf.d/default.conf"]
      }

      template {
        data = <<EOF
upstream signoz-backend {
    server 127.0.0.1:8080;
}

server {
    listen 3301;
    server_name _;
    
    gzip on;
    gzip_types text/css application/javascript application/json;
    
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
    
    location /api {
        proxy_pass http://signoz-backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

        destination = "local/nginx.conf"
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
          path         = "/health"
          interval     = "10s"
          timeout      = "3s"
          address_mode = "host"
        }
      }
    }
  }
}