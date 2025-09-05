variable "branch_or_sha" {
  type = string
  default = "main"
}

job "analytics-production" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  node_pool = "production"

  # To run swetrix we need Clickhouse, Frontend, API, Redis.
  # This is the frontend ue see
  group "frontend" {
    count = 1
    update {
      canary = 1
      auto_promote = true
      auto_revert = true
    }
    network {
      port "swetrix_frontend_port" { to =  3000 }

      dns {
        servers = ["10.88.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    service {
      port = "swetrix_frontend_port"
      tags = ["live"]
      canary_tags = ["canary"]
      check {
        type = "http"
        port = "swetrix_frontend_port"
        path = "/ping"
        interval = "10s"
        timeout = "1s"
      }
    }

    task "web" {
      driver = "podman"

      config {
        image = "docker.io/swetrix/swetrix-fe:v3.3.1"
        ports = ["swetrix_frontend_port"]
      }

      resources {
        cpu    = 1000
        memory = 2048
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
        API_URL = https://analytics.lib.princeton.edu/api/
        DISABLE_MARKETING_PAGES=true
        EOF
      }
    }
  }
  # These collect all the events - I think it's what we'll scale, and what servers will look at. Which I think means it's what will be at analytics.lib.princeton.edu?
  # Maybe analytics.lib.princeton.edu/api
  group "backend" {
    count = 1
    network {
      port "swetrix_api_port" { to =  5005 }

      dns {
        servers = ["10.88.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    update {
      canary = 1
      auto_promote = true
      auto_revert = true
    }

    service {
      port = "swetrix_api_port"
      tags = ["live"]
      canary_tags = ["canary"]
      check {
        type = "http"
        port = "swetrix_api_port"
        path = "/ping"
        interval = "10s"
        timeout = "1s"
      }
    }

    task "web" {
      driver = "podman"

      config {
        image = "docker.io/swetrix/swetrix-api:v3.3.1"
        ports = ["swetrix_api_port"]
      }

      resources {
        cpu    = 1000
        memory = 2048
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        # We'll have to use consul connect or load balance the clickhouse nodes later.
        # Right now consul connect isn't installed on the cluster, so we'll just use the one IP/Port.
        data = <<EOF
        {{- with nomadVar "nomad/jobs/analytics-production" -}}
        JWT_ACCESS_TOKEN_SECRET = {{ .ACCESS_TOKEN_SECRET }}
        JWT_REFRESH_TOKEN_SECRET = {{ .REFRESH_TOKEN_SECRET }}
        EMAIL = admin@example.com
        PASSWORD = {{ .ADMIN_PASSWORD }}
        REDIS_HOST = {{ range service "analytics-production-cache" }}{{ .Address }}{{ end }}
        REDIS_PORT = {{ range service "analytics-production-cache" }}{{ .Port }}{{ end }}
        CLICKHOUSE_HOST = http://{{ range service "analytics-production-clickhouse" }}{{ .Address }}{{ end }}
        CLICKHOUSE_PORT = {{ range service "analytics-production-clickhouse" }}{{ .Port }}{{ end }}
        CLICKHOUSE_PASSWORD = {{ .DB_PASSWORD }}
        {{- end -}}
        EOF
      }
    }
  }
  # This is the redis cache.
  group "cache" {
    count = 1

    network {
      port "redis_port" { to =  6379 }

      dns {
        servers = ["10.88.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    # This makes the disk for Redis 300 MB and it should move around nodes, as long as the job's not stopped.
    ephemeral_disk {
      sticky = true
      migrate = true
      size = 300
    }

    service {
      port = "redis_port"
      check {
        name     = "alive"
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "redis" {
      driver = "podman"

      config {
        image = "docker.io/library/redis:7.2-alpine"
        ports = ["redis_port"]
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/analytics-production" -}}
        REDIS_PORT = 6379
        REDIS_USER = default
        REDIS_PASSWORD = {{ .DB_PASSWORD }}
        {{- end -}}
        EOF
      }
    }
  }
  # For analysis purposes we're not gonna run a real clickhouse cluster - if we go with this, we need to set up a high-availability clickhouse with three keeper nodes and at least two replicas: https://clickhouse.com/docs/architecture/replication
  # Most of this configuration is converted from https://github.com/Swetrix/selfhosting/blob/main/compose.yaml
  group "clickhouse" {
    count = 1

    network {
      port "http" { to =  8123}

      dns {
        servers = ["10.88.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    volume "clickhouse_data" {
      type      = "host"
      read_only = false
      source    = "clickhouse_data"
    }

    service {
      port = "http"
      check {
        type = "http"
        port = "http"
        path = "/ping"
        interval = "10s"
        timeout = "1s"
      }
    }

    task "server" {
      driver = "podman"

      # This is a very small amount of resources for clickhouse, but we're gonna try it.
      resources {
        cpu    = 2048
        memory = 6000
      }

      config {
        image = "docker.io/clickhouse/clickhouse-server:24.10-alpine"
        ports = ["http"]
        cap_add = [
          "SYS_NICE"
        ]
        ulimit {
          nofile = "262144:262144"
        }
        volumes = [
          "local/clickhouse-server-config:/etc/clickhouse-server/config.d",
          "local/clickhouse-user-config:/etc/clickhouse-server/users.d"
        ]
      }

      volume_mount {
        volume      = "clickhouse_data"
        destination = "/var/lib/clickhouse"
        read_only   = false
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/analytics-production" -}}
        CLICKHOUSE_DATABASE = analytics
        CLICKHOUSE_USER = default
        CLICKHOUSE_PORT = 8123
        CLICKHOUSE_PASSWORD = {{ .DB_PASSWORD }}
        {{- end -}}
        EOF
      }

      template {
        data = <<EOH
        <clickhouse>
            <listen_host>0.0.0.0</listen_host>
        </clickhouse>
        EOH
        destination = "local/clickhouse-server-config/listen_host.xml"
      }

      template {
        data = <<EOH
        <clickhouse>
          <logger>
            <level>warning</level>
            <console>true</console>
          </logger>
          <query_thread_log remove="remove"/>
          <query_log remove="remove"/>
          <text_log remove="remove"/>
          <trace_log remove="remove"/>
          <metric_log remove="remove"/>
          <asynchronous_metric_log remove="remove"/>
          <session_log remove="remove"/>
          <part_log remove="remove"/>
        </clickhouse>
        EOH

        destination = "local/clickhouse-server-config/reduce-logs.xml"
      }

      template {
        data = <<EOH
        <clickhouse>
          <mark_cache_size>536870912</mark_cache_size>
          <concurrent_threads_soft_limit_num>1</concurrent_threads_soft_limit_num>
        </clickhouse>
        EOH

        destination = "local/clickhouse-server-config/preserve-ram-config.xml"
      }

      template {
        data = <<EOH
        <clickhouse>
          <profiles>
            <default>
              <log_queries>0</log_queries>
              <log_query_threads>0</log_query_threads>
            </default>
          </profiles>
        </clickhouse>
        EOH

        destination = "local/clickhouse-user-config/disable-user-logging.xml"
      }

      template {
        data = <<EOH
        <clickhouse>
          <profiles>
            <default>
              <max_block_size>2048</max_block_size>
              <max_download_threads>1</max_download_threads>
              <input_format_parallel_parsing>0</input_format_parallel_parsing>
              <output_format_parallel_formatting>0</output_format_parallel_formatting>
            </default>
          </profiles>
        </clickhouse>
        EOH

        destination = "local/clickhouse-user-config/preserve-ram-user.xml"
      }
    }
  }
}
