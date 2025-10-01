# SigNoz deployment (Nomad + Podman), upstream-like layout
variable "branch_or_sha" {
  type    = string
  default = "main"
}

job "signoz" {
  datacenters = ["dc1"]
  type        = "service"

  # Rolling updates
  update {
    max_parallel      = 1
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
    auto_promote      = true
    canary            = 1  # required when auto_promote = true
  }

  # Infrastructure group
  group "infrastructure" {
    count = 1

    network {
      mode = "bridge"

      port "zookeeper" {
        to = 2181
      }
      port "zookeeper_metrics" {
        to = 9141
      }
      port "clickhouse_http" {
        static = 8123
        to     = 8123
      }
      port "clickhouse_native" {
        static = 9000
        to     = 9000
      }
      port "clickhouse_metrics" {
        to = 9363
      }
    }

    # Init: fetch histogramQuantile helper into user_scripts
    task "init-clickhouse" {
      driver = "podman"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        image   = "clickhouse/clickhouse-server:25.5.6"
        command = "bash"
        args = [
          "-c",
          <<EOF
version="v0.0.1"
node_os=$(uname -s | tr '[:upper:]' '[:lower:]')
node_arch=$(uname -m | sed s/aarch64/arm64/ | sed s/x86_64/amd64/)
echo "Fetching histogram-binary for ${node_os}/${node_arch}"
cd /tmp
wget -O histogram-quantile.tar.gz "https://github.com/SigNoz/signoz/releases/download/histogram-quantile%2F${version}/histogram-quantile_${node_os}_${node_arch}.tar.gz"
tar -xvzf histogram-quantile.tar.gz
cp histogram-quantile /var/lib/clickhouse/user_scripts/histogramQuantile
EOF
        ]
        volumes = [
          "local/user_scripts:/var/lib/clickhouse/user_scripts/"
        ]
      }

      resources {
        cpu = 200
        memory = 256
      }
    }

    # ZooKeeper
    task "zookeeper" {
      driver = "podman"
      config {
        image = "signoz/zookeeper:3.7.1"
        ports = ["zookeeper", "zookeeper_metrics"]
        volumes = ["local/zookeeper-data:/bitnami/zookeeper"]
      }

      # ensure the data dir exists
      template {
        data        = "# placeholder\n"
        destination = "local/zookeeper-data/.keep"
      }

      env {
        ZOO_SERVER_ID                       = "1"
        ALLOW_ANONYMOUS_LOGIN               = "yes"
        ZOO_AUTOPURGE_INTERVAL              = "1"
        ZOO_ENABLE_PROMETHEUS_METRICS       = "yes"
        ZOO_PROMETHEUS_METRICS_PORT_NUMBER  = "9141"
      }

      resources {
        cpu = 500
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

    # ClickHouse
    task "clickhouse" {
      driver = "podman"
      config {
        image = "clickhouse/clickhouse-server:25.5.6"
        ports = ["clickhouse_http", "clickhouse_native", "clickhouse_metrics"]
        volumes = [
          "local/config.xml:/etc/clickhouse-server/config.xml",
          "local/users.xml:/etc/clickhouse-server/users.xml",
          "local/custom-function.xml:/etc/clickhouse-server/custom-function.xml",
          "local/user_scripts:/var/lib/clickhouse/user_scripts/",
          "local/cluster.xml:/etc/clickhouse-server/config.d/cluster.xml",
          "local/clickhouse-data:/var/lib/clickhouse/"
        ]
        # Raise nofile for CH
        ulimit = { nofile = "262144:262144" }
      }

      # ensure the data dir exists
      template {
        data        = "# placeholder\n"
        destination = "local/clickhouse-data/.keep"
      }

      env {
        CLICKHOUSE_SKIP_USER_SETUP = "1"
      }

      # Base config
      template {
        data = <<EOH
<clickhouse>
  <logger><level>debug</level><console>1</console></logger>
  <tcp_port>9000</tcp_port>
  <http_port>8123</http_port>
  <prometheus>
    <endpoint>/metrics</endpoint><port>9363</port>
    <metrics>true</metrics><events>true</events><asynchronous_metrics>true</asynchronous_metrics>
  </prometheus>
  <path>/var/lib/clickhouse/</path>
  <tmp_path>/var/lib/clickhouse/tmp/</tmp_path>
  <user_files_path>/var/lib/clickhouse/user_files/</user_files_path>
  <format_schema_path>/var/lib/clickhouse/format_schemas/</format_schema_path>
  <user_directories>
    <users_xml><path>users.xml</path></users_xml>
    <local_directory><path>/var/lib/clickhouse/access/</path></local_directory>
  </user_directories>
</clickhouse>
EOH
        destination = "local/config.xml"
      }

      # User
      template {
        data = <<EOH
<users>
  <default>
    <password></password>
    <networks><ip>::/0</ip></networks>
    <profile>default</profile>
    <quota>default</quota>
  </default>
</users>
EOH
        destination = "local/users.xml"
      }

      # Custom functions placeholder
      template {
        data = <<EOH
<clickhouse><functions></functions></clickhouse>
EOH
        destination = "local/custom-function.xml"
      }

      # Single-node cluster named "cluster"
      template {
        data = <<EOH
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
        cpu = 2000
        memory = 4096
      }

      # HTTP service (8123)
      service {
        name = "clickhouse"
        port = "clickhouse_http"
        check {
          type     = "http"
          path     = "/ping"
          interval = "30s"
          timeout  = "5s"
        }
      }

      # Native TCP service (9000) for DSNs
      service {
        name = "clickhouse-native"
        port = "clickhouse_native"
        check {
          type     = "tcp"
          interval = "30s"
          timeout  = "5s"
        }
      }
    }
  }

  # Application group
  group "signoz-app" {
    count = 1

    network {
      mode = "bridge"

      port "signoz" {
        static = 8080
        to     = 8080
      }
      port "otel_grpc" {
        static = 4317
        to     = 4317
      }
      port "otel_http" {
        static = 4318
        to     = 4318
      }
    }

    # Sync schema before app (blocks start of other tasks in group)
    task "schema-migrator-sync" {
      driver = "podman"
      lifecycle {
        hook = "prestart"
        sidecar = false
      }
      config {
        image   = "signoz/signoz-schema-migrator:v0.129.6"
        command = "sync"
        args    = ["--dsn=tcp://clickhouse-native.service.consul:9000", "--up="]
      }
      resources {
        cpu = 200
        memory = 256
      }
    }

    # SigNoz app
    task "signoz" {
      driver = "podman"
      config {
        image   = "signoz/signoz:v0.96.1"
        ports   = ["signoz"]
        command = "--config=/root/config/prometheus.yml"
        volumes = [
          "local/prometheus.yml:/root/config/prometheus.yml",
          "local/dashboards:/root/config/dashboards",
          "local/signoz-sqlite:/var/lib/signoz/"
        ]
      }

      # ensure sqlite dir exists
      template {
        data        = "# placeholder\n"
        destination = "local/signoz-sqlite/.keep"
      }

      env {
        SIGNOZ_ALERTMANAGER_PROVIDER         = "signoz"
        SIGNOZ_TELEMETRYSTORE_CLICKHOUSE_DSN = "tcp://clickhouse-native.service.consul:9000"
        SIGNOZ_SQLSTORE_SQLITE_PATH          = "/var/lib/signoz/signoz.db"
        DASHBOARDS_PATH                      = "/root/config/dashboards"
        STORAGE                              = "clickhouse"
        GODEBUG                              = "netdns=go"
        TELEMETRY_ENABLED                    = "true"
        DEPLOYMENT_TYPE                      = "nomad-cluster"
        DOT_METRICS_ENABLED                  = "true"
      }

      template {
        data = <<EOH
global:
  scrape_interval: 60s
scrape_configs:
  - job_name: 'signoz'
    static_configs:
      - targets: ['localhost:8080']
EOH
        destination = "local/prometheus.yml"
      }

      # (optional) place JSON dashboards here if you have them in repo
      template {
        data = "# placeholder\n"
        destination = "local/dashboards/.keep"
      }

      resources {
        cpu = 1000
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
          "traefik.http.routers.signoz.rule=Host(`signoz.${attr.unique.network.ip-address}.nip.io`)"
        ]
      }
    }

    # OpenTelemetry Collector
    task "otel-collector" {
      driver = "podman"
      config {
        image = "signoz/signoz-otel-collector:v0.129.6"
        ports = ["otel_grpc", "otel_http"]
        volumes = [
          "local/otel-collector-config.yaml:/etc/otel-collector-config.yaml",
          "local/otel-collector-opamp-config.yaml:/etc/manager-config.yaml"
        ]
      }

      env {
        OTEL_RESOURCE_ATTRIBUTES        = "host.name=signoz-host,os.type=linux"
        LOW_CARDINAL_EXCEPTION_GROUPING = "false"
      }

      # Render config with Consul DNS to ClickHouse
      template {
        data = <<EOH
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
  clickhousetraces:
    datasource: tcp://clickhouse-native.service.consul:9000/signoz_traces
    low_cardinal_exception_grouping: ${LOW_CARDINAL_EXCEPTION_GROUPING}
    use_new_schema: true
  signozclickhousemetrics:
    dsn: tcp://clickhouse-native.service.consul:9000/signoz_metrics
  clickhouselogsexporter:
    dsn: tcp://clickhouse-native.service.consul:9000/signoz_logs
    timeout: 10s
    use_new_schema: true

service:
  telemetry:
    logs:
      encoding: json
  extensions:
    - health_check
    - pprof
  pipelines:
    traces:
      receivers: [otlp]
      processors: [signozspanmetrics/delta, batch]
      exporters: [clickhousetraces]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [signozclickhousemetrics]
    metrics/prometheus:
      receivers: [prometheus]
      processors: [batch]
      exporters: [signozclickhousemetrics]
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [clickhouselogsexporter]
EOH
        destination = "local/otel-collector-config.yaml"
        perms       = "0644"
      }

      template {
        data = <<EOH
# OpAMP configuration for collector management
capabilities:
  accepts_remote_config: true
  reports_remote_config: true
server:
  ws:
    endpoint: ws://signoz:4320/ws
    tls:
      insecure: true
EOH
        destination = "local/otel-collector-opamp-config.yaml"
      }

      resources {
        cpu = 1000
        memory = 1024
      }

      service {
        name = "otel-collector-grpc"
        port = "otel_grpc"
        check {
          type = "tcp"
          interval = "30s"
          timeout = "5s"
        }
      }
      service {
        name = "otel-collector-http"
        port = "otel_http"
        check {
          type = "tcp"
          interval = "30s"
          timeout = "5s"
        }
      }
    }

    # Async migrator (kept separate like upstream)
    task "schema-migrator-async" {
      driver = "podman"
      config {
        image   = "signoz/signoz-schema-migrator:v0.129.6"
        command = "async"
        args    = ["--dsn=tcp://clickhouse-native.service.consul:9000", "--up="]
      }
      resources {
        cpu = 200
        memory = 256
      }
    }
  }
}

