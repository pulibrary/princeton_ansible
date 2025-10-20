variable "branch_or_sha" {
  type = string
  default = "main"
}

job "analytics-production" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  node_pool = "production"

  # To run Rybbit we need Clickhouse, Frontend, API, Redis.
  # This is the frontend ue see
  group "frontend" {
    count = 1
    update {
      canary = 1
      auto_promote = true
      auto_revert = true
    }
    network {
      port "rybbit_frontend_port" { to =  3002 }

      dns {
        servers = ["10.88.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    service {
      port = "rybbit_frontend_port"
      tags = ["live"]
      canary_tags = ["canary"]
      check {
        type = "http"
        port = "rybbit_frontend_port"
        path = "/"
        interval = "10s"
        timeout = "1s"
      }
    }

    task "web" {
      driver = "podman"

      config {
        image = "ghcr.io/rybbit-io/rybbit-client:v1.6.1"
        ports = ["rybbit_frontend_port"]
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
        NODE_ENV = production
        NEXT_PUBLIC_BACKEND_URL = https://analytics.lib.princeton.edu
        NEXT_PUBLIC_DISABLE_SIGNUP = true
        EOF
      }
    }
  }
  # These are where events get sent, and will be what scales - it's at analytics.princeton.edu/api/
  group "backend" {
    count = 1
    network {
      port "rybbit_api_port" { to = 3001 }

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
      port = "rybbit_api_port"
      tags = ["live"]
      canary_tags = ["canary"]
      check {
        type = "http"
        port = "rybbit_api_port"
        path = "/api/health"
        interval = "10s"
        timeout = "1s"
      }
    }

    task "web" {
      driver = "podman"

      config {
        image = "ghcr.io/rybbit-io/rybbit-backend:v1.6.1"
        ports = ["rybbit_api_port"]
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
        NODE_ENV = production
        CLICKHOUSE_HOST = http://{{ range service "analytics-production-clickhouse" }}{{ .Address }}:{{ .Port }}{{ end }}
        CLICKHOUSE_PASSWORD = {{ .DB_PASSWORD }}
        CLICKHOUSE_DB = analytics
        POSTGRES_HOST = {{ .POSTGRES_HOST }}
        POSTGRES_PORT = 5432
        POSTGRES_DB = {{ .DB_NAME }}
        POSTGRES_USER = {{ .DB_USER }}
        POSTGRES_PASSWORD = {{ .DB_PASSWORD }}
        BETTER_AUTH_SECRET = {{ .ACCESS_TOKEN_SECRET }}
        DISABLE_SIGNUP = true
        DISABLE_TELEMETRY = true
        DOMAIN_NAME = analytics.lib.princeton.edu
        BASE_URL = https://analytics.lib.princeton.edu
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
        image = "docker.io/clickhouse/clickhouse-server:25.4.2"
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
        CLICKHOUSE_DB = analytics
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
          <latency_log remove="remove"/>
          <processors_profile_log remove="remove"/>
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
              <log_processors_profiles>0</log_processors_profiles>
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
