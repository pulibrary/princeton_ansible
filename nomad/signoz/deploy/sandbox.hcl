# SigNoz deployment (Nomad + Podman), upstream-like layout
variable "branch_or_sha" {
  type    = string
  default = "main"
}

job "signoz" {
  datacenters = ["dc1"]
  node_pool   = "sandbox"
  type        = "service"

  update {
    max_parallel      = 1
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
    auto_promote      = true
    canary            = 1
  }

  group "signozstack" {
    count = 1

    network {
      mode = "host"

      port "zookeeper" {
        static = 2181
      }
      port "zookeeper_metrics" {
        static = 9141
      }
      port "clickhouse_http" {
        static = 8123
      }
      port "clickhouse_native" {
        static = 9000
      }
      port "clickhouse_metrics" {
        static = 9363
      }
      port "signoz" {
        static = 8080
      }
      port "otel_grpc" {
        static = 4317
      }
      port "otel_http" {
        static = 4318
      }
    }

    task "zookeeper" {
      driver = "podman"

      config {
        image = "docker.io/signoz/zookeeper:3.7.1"
        ports = ["zookeeper", "zookeeper_metrics"]
      }

      env {
        ZOO_SERVER_ID                      = "1"
        ALLOW_ANONYMOUS_LOGIN              = "yes"
        ZOO_AUTOPURGE_INTERVAL             = "1"
        ZOO_ENABLE_PROMETHEUS_METRICS      = "yes"
        ZOO_PROMETHEUS_METRICS_PORT_NUMBER = "9141"
      }

      resources {
        cpu    = 500
        memory = 512
      }

      service {
        name = "zookeeper"
        port = "zookeeper"

        check {
          type     = "tcp"
          interval = "30s"
          timeout  = "5s"
        }
      }
    }

    task "clickhouse" {
      driver = "podman"

      artifact {
        source      = "https://github.com/SigNoz/signoz/releases/download/histogram-quantile%2Fv0.0.1/histogram-quantile_linux_amd64.tar.gz"
        destination = "local/bin"
      }

      config {
        image   = "docker.io/clickhouse/clickhouse-server:24.5.6"
        volumes = [
          "local/config.xml:/etc/clickhouse-server/config.xml",
          "local/users.xml:/etc/clickhouse-server/users.xml",
          "local/custom-function.xml:/etc/clickhouse-server/custom-function.xml",
          "local/bin/histogram-quantile:/var/lib/clickhouse/user_scripts/histogramQuantile",
          "local/cluster.xml:/etc/clickhouse-server/config.d/cluster.xml",
          "local/clickhouse-data:/var/lib/clickhouse/",
        ]
        ulimit = {
          nofile = "262144:262144"
        }
        ports = ["clickhouse_http", "clickhouse_native", "clickhouse_metrics"]
      }

      template {
        data        = "# placeholder\n"
        destination = "local/clickhouse-data/.keep"
      }

      env {
        CLICKHOUSE_SKIP_USER_SETUP = "1"
      }

      template {
        data        = <<EOH
<clickhouse>
  <logger>
    <level>debug</level>
    <console>1</console>
    <log>/var/log/clickhouse-server/clickhouse-server.log</log>
    <errorlog>/var/log/clickhouse-server/clickhouse-server.err.log</errorlog>
    <size>1000M</size>
    <count>10</count>
  </logger>
  <listen_host>::</listen_host>
  <tcp_port>9000</tcp_port>
  <http_port>8123</http_port>
  <prometheus>
    <endpoint>/metrics</endpoint>
    <port>9363</port>
    <metrics>true</metrics>
    <events>true</events>
    <asynchronous_metrics>true</asynchronous_metrics>
  </prometheus>
  <path>/var/lib/clickhouse/</path>
  <tmp_path>/var/lib/clickhouse/tmp/</tmp_path>
  <user_files_path>/var/lib/clickhouse/user_files/</user_files_path>
  <format_schema_path>/var/lib/clickhouse/format_schemas/</format_schema_path>
  <user_directories>
    <users_xml>
      <path>users.xml</path>
    </users_xml>
    <local_directory>
      <path>/var/lib/clickhouse/access/</path>
    </local_directory>
  </user_directories>
</clickhouse>
EOH
        destination = "local/config.xml"
      }

      template {
        data        = <<EOH
<clickhouse>
  <users>
    <default>
      <password></password>
      <networks>
        <ip>::/0</ip>
      </networks>
      <profile>default</profile>
      <quota>default</quota>
    </default>
  </users>
  <profiles>
    <default>
      <max_memory_usage>10000000000</max_memory_usage>
    </default>
  </profiles>
  <quotas>
    <default>
      <interval>
        <duration>3600</duration>
        <queries>0</queries>
        <errors>0</errors>
        <result_rows>0</result_rows>
        <read_rows>0</read_rows>
        <execution_time>0</execution_time>
      </interval>
    </default>
  </quotas>
</clickhouse>
EOH
        destination = "local/users.xml"
      }

      template {
        data        = <<EOH
<clickhouse><functions></functions></clickhouse>
EOH
        destination = "local/custom-function.xml"
      }

      template {
        data        = <<EOH
<clickhouse>
  <remote_servers>
    <cluster>
      <shard>
        <replica>
          <host>localhost</host>
          <port>9000</port>
        </replica>
      </shard>
    </cluster>
  </remote_servers>
</clickhouse>
EOH
        destination = "local/cluster.xml"
      }

      resources {
        cpu    = 2000
        memory = 4096
      }

      service {
        name = "clickhouse-http"
        port = "clickhouse_http"

        check {
          type     = "http"
          path     = "/ping"
          interval = "30s"
          timeout  = "5s"
        }
      }

      service {
        name = "clickhouse"
        port = "clickhouse_native"

        check {
          type     = "tcp"
          interval = "30s"
          timeout  = "5s"
        }
      }
    }

    task "schema-migrator-sync" {
      driver = "podman"

      lifecycle {
        hook    = "poststart"
        sidecar = false
      }

      config {
        image      = "docker.io/signoz/signoz-schema-migrator:v0.129.6"
        entrypoint = ["/bin/sh"]
        command    = "-c"
        args       = [
          "sync",
          "--dsn", "tcp://${NOMAD_ADDR_clickhouse_native}",
          "--cluster-name", "",
          "--replication=false"
        ]
      }

      env {
        CLICKHOUSE_ADDR = "${NOMAD_ADDR_clickhouse_native}"
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    task "signoz" {
      driver = "podman"

      config {
        image   = "docker.io/signoz/query-service:0.52.0"
        command = "--config=/root/config/prometheus.yml"
        volumes = [
          "local/prometheus.yml:/root/config/prometheus.yml",
          "local/dashboards:/root/config/dashboards",
          "local/signoz-sqlite:/var/lib/signoz/",
        ]
        ports = ["signoz"]
      }

      template {
        data        = "# placeholder\n"
        destination = "local/signoz-sqlite/.keep"
      }

      env {
        CLICKHOUSE_ADDRESS = "tcp://clickhouse.service.consul:9000"
        CH_HOST = "clickhouse.service.consul"
        CH_PORT = "9000"
        SIGNOZ_ALERTMANAGER_PROVIDER = "signoz"
        SIGNOZ_SQLSTORE_SQLITE_PATH  = "/var/lib/signoz/signoz.db"
        DASHBOARDS_PATH              = "/root/config/dashboards"
        STORAGE                      = "clickhouse"
        GODEBUG                      = "netdns=go"
        TELEMETRY_ENABLED            = "true"
        DEPLOYMENT_TYPE              = "nomad-cluster"
        DOT_METRICS_ENABLED          = "true"
      }

      template {
        data        = <<EOH
global:
  scrape_interval: 60s
scrape_configs:
  - job_name: 'signoz'
    static_configs:
      - targets: ['localhost:8080']
EOH
        destination = "local/prometheus.yml"
      }

      template {
        data        = "# placeholder\n"
        destination = "local/dashboards/.keep"
      }

      resources {
        cpu    = 1000
        memory = 2048
      }

      service {
        name = "signoz"
        port = "signoz"

        check {
          type     = "http"
          path     = "/api/v1/health"
          interval = "30s"
          timeout  = "5s"
        }
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.signoz.rule=Host(`signoz.${attr.unique.network.ip-address}.nip.io`)",
        ]
      }

      restart {
        attempts = 10
        interval = "30m"
        delay    = "15s"
        mode     = "delay"
      }
    }

    task "otel-collector" {
      driver = "podman"

      config {
        image   = "docker.io/signoz/signoz-otel-collector:v0.129.6"
        volumes = [
          "local/otel-collector-config.yaml:/etc/otel-collector-config.yaml",
          "local/otel-collector-opamp-config.yaml:/etc/manager-config.yaml",
        ]
        ports = ["otel_grpc", "otel_http"]
        args  = ["--config=/etc/otel-collector-config.yaml"]
      }

      env {
        OTEL_RESOURCE_ATTRIBUTES        = "host.name=signoz-host,os.type=linux"
        LOW_CARDINAL_EXCEPTION_GROUPING = "false"
      }

      restart {
        attempts = 10
        interval = "30m"
        delay    = "15s"
        mode     = "delay"
      }

      template {
        data        = <<EOH
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

  prometheus:
    config:
      global:
        scrape_interval: 60s
      scrape_configs:
        - job_name: otel-collector
          static_configs:
            - targets: [localhost:8888]
              labels:
                job_name: otel-collector

processors:
  batch:
    send_batch_size: 10000
    send_batch_max_size: 11000
    timeout: 10s
  resourcedetection:
    detectors: [env, system]
    timeout: 2s
  signozspanmetrics/delta:
    metrics_exporter: signozclickhousemetrics
    metrics_flush_interval: 60s
    latency_histogram_buckets: [100us, 1ms, 2ms, 6ms, 10ms, 50ms, 100ms, 250ms, 500ms, 1000ms, 1400ms, 2000ms, 5s, 10s, 20s, 40s, 60s]
    dimensions_cache_size: 100000
    aggregation_temporality: AGGREGATION_TEMPORALITY_DELTA
    enable_exp_histogram: true
    dimensions:
      - name: service.namespace
        default: default
      - name: deployment.environment
        default: default
      - name: signoz.collector.id
      - name: service.version
      - name: browser.platform
      - name: browser.mobile
      - name: k8s.cluster.name
      - name: k8s.node.name
      - name: k8s.namespace.name
      - name: host.name
      - name: host.type
      - name: container.name

extensions:
  health_check:
    endpoint: 0.0.0.0:13133
  pprof:
    endpoint: 0.0.0.0:1777

exporters:
  clickhouseexporter:
    dsn: tcp://clickhouse.service.consul:9000?dial_timeout=10s&compress=lz4
    logs:
      database: signoz_logs
      ttl: 48h

    traces:
      database: signoz_traces
      ttl: 48h

    metrics:
      database: signoz_metrics
      ttl: 48h

service:
  telemetry:
    logs:
      encoding: json
  extensions: [health_check, pprof]
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [clickhouse]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [clickhouse]
    metrics/prometheus:
      receivers: [prometheus]
      processors: [batch]
      exporters: [clickhouse]
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [clickhouse]
EOH
        destination = "local/otel-collector-config.yaml"
        perms       = "0644"
      }

      template {
        data        = <<EOH
# OpAMP configuration for collector management
capabilities:
  accepts_remote_config: true
  reports_remote_config: true
server:
  ws:
    endpoint: ws://localhost:4320/ws
    tls:
      insecure: true
EOH
        destination = "local/otel-collector-opamp-config.yaml"
      }

      resources {
        cpu    = 1000
        memory = 1024
      }

      service {
        name = "otel-collector-grpc"
        port = "otel_grpc"

        check {
          type     = "tcp"
          interval = "30s"
          timeout  = "5s"
        }
      }

      service {
        name = "otel-collector-http"
        port = "otel_http"

        check {
          type     = "tcp"
          interval = "30s"
          timeout  = "5s"
        }
      }
    }

    task "schema-migrator-async" {
      driver = "podman"

      lifecycle {
        hook    = "poststart"
        sidecar = false
      }

      config {
        image      = "docker.io/signoz/signoz-schema-migrator:v0.129.6"
        entrypoint = ["/bin/sh"]
        command    = "-c"
        args       = [
          "sync",
          "--dsn", "tcp://${NOMAD_ADDR_clickhouse_native}",
          "--cluster-name", "",
          "--replication=false"
        ]
      }
      env {
        CLICKHOUSE_ADDRESS             = "clickhouse.service.consul:9000"
        SIGNOZ_ALERTMANAGER_PROVIDER   = "signoz"
        SIGNOZ_SQLSTORE_SQLITE_PATH    = "/var/lib/signoz/signoz.db"
        DASHBOARDS_PATH                = "/root/config/dashboards"
        STORAGE                        = "clickhouse"
        GODEBUG                        = "netdns=go"
        TELEMETRY_ENABLED              = "true"
        DEPLOYMENT_TYPE                = "nomad-cluster"
        DOT_METRICS_ENABLED            = "true"
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
