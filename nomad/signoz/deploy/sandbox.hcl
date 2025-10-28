variable "branch_or_sha" {
  type    = string
  default = "main"
}

variable "signoz_version" {
  type    = string
  default = "v0.98.0"
}

variable "otelcol_tag" {
  type    = string
  default = "v0.129.7"
}

job "signoz" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "all"

  group "signoz-all" {
    count = 1

    # hard pin
    # value of `nomad node status`
    # ` nomad node status -verbose 1746c3f9`
    constraint {
      attribute = "${node.unique.id}"
      value = "1746c3f9-84a0-5a53-890c-d8aea69c0a02"
    }

    network {
      dns {
        servers = ["10.88.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
      mode = "host"
      port "otlp_grpc" {
        static = 4317
      }
      port "otlp_http" {
        static = 4318
      }
    }

    # Zookeeper task
    task "zookeeper" {
      driver = "podman"

      config {
        image = "docker.io/signoz/zookeeper:3.7.1"
        network_mode = "host"
        volumes = [
          # persistent state
          # selinux needs `sudo chcon -Rt container_file_t /data/clickhouse /data/clickhouse-logs /data/zookeeper /data/signoz`
          "/data/zookeeper:/bitnami/zookeeper"
        ]
      }

      env {
        ZOO_SERVER_ID                      = "1"
        ALLOW_ANONYMOUS_LOGIN              = "yes"
        ZOO_AUTOPURGE_INTERVAL             = "1"
        #        JAVA_TOOL_OPTIONS                  = "-Dzookeeper.admin.enableServer=false"
        ZOO_ENABLE_ADMIN_SERVER            = "no"
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }

    # ClickHouse task
    task "clickhouse" {
      driver = "podman"

      config {
        image = "docker.io/clickhouse/clickhouse-server:25.5.6"
        network_mode = "host"

        volumes = [
          "local/clickhouse-config.xml:/etc/clickhouse-server/config.xml",
          "local/clickhouse-users.xml:/etc/clickhouse-server/users.xml",
          # persistent state
          # selinux needs `sudo chcon -Rt container_file_t /data/clickhouse /data/clickhouse-logs /data/zookeeper /data/signoz`
          "/data/clickhouse:/var/lib/clickhouse",
          "/data/clickhouse-logs:/var/log/clickhouse-server"
        ]
      }

      env {
        CLICKHOUSE_SKIP_USER_SETUP = "1"
      }

      template {
        destination = "local/clickhouse-config.xml"
        data = <<EOF
<clickhouse>
    <logger>
        <level>trace</level>
        <log>/var/log/clickhouse-server/clickhouse-server.log</log>
        <errorlog>/var/log/clickhouse-server/clickhouse-server.err.log</errorlog>
        <size>1000M</size>
        <count>10</count>
    </logger>

    <listen_host>0.0.0.0</listen_host>
    <http_port>8123</http_port>
    <tcp_port>9000</tcp_port>

    <remote_servers>
      <cluster>
        <shard>
          <replica>
            <host>127.0.0.1</host>
            <port>9000</port>
          </replica>
        </shard>
      </cluster>
    </remote_servers>

    <distributed_ddl>
      <path>/clickhouse/task_queue/ddl</path>
    </distributed_ddl>

    <interserver_http_port>9009</interserver_http_port>
    <interserver_http_host>127.0.0.1</interserver_http_host>

    <zookeeper>
      <node>
        <host>127.0.0.1</host>
        <port>2181</port>
      </node>
    </zookeeper>

    <macros>
      <replica>replica_1</replica>
      <shard>1</shard>
    </macros>

    <path>/var/lib/clickhouse/</path>
    <tmp_path>/var/lib/clickhouse/tmp/</tmp_path>
    <user_files_path>/var/lib/clickhouse/user_files/</user_files_path>
    <user_scripts_path>/var/lib/clickhouse/user_scripts/</user_scripts_path>
    <format_schema_path>/var/lib/clickhouse/format_schemas/</format_schema_path>

    <user_directories>
        <users_xml>
            <path>/etc/clickhouse-server/users.xml</path>
        </users_xml>
    </user_directories>

    <zookeeper>
        <node>
            <host>127.0.0.1</host>
            <port>2181</port>
        </node>
    </zookeeper>

    <macros>
        <replica>replica_1</replica>
        <shard>1</shard>
    </macros>
</clickhouse>
EOF
      }

      template {
        destination = "local/clickhouse-users.xml"
        data = <<EOF
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
            <max_memory_usage>22000000000</max_memory_usage>
            <max_threads>0</max_threads>
            <max_partitions_per_insert_block>200</max_partitions_per_insert_block>
            <use_uncompressed_cache>0</use_uncompressed_cache>
            <load_balancing>random</load_balancing>
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
EOF
      }

      resources {
        cpu    = 4000
        memory = 8192
      }
    }

    # Wait for ClickHouse to be ready
    task "wait-clickhouse" {
      driver = "podman"

      lifecycle {
        hook    = "poststart"
        sidecar = false
      }

      config {
        image = "docker.io/library/busybox:latest"
        network_mode = "host"
        command = "sh"
         args = ["-c", "until [ \"$(wget -qO- http://127.0.0.1:8123/ping 2>/dev/null)\" = \"Ok\" ]; do echo 'Waiting for ClickHouse…'; sleep 2; done; echo 'ClickHouse is ready!'"]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }

    # Schema Migrator Sync
    task "schema-migrator-sync" {
      driver = "podman"

      lifecycle {
        hook    = "poststart"
        sidecar = false
      }

      config {
        image = "docker.io/signoz/signoz-schema-migrator:${var.otelcol_tag}"
        network_mode = "host"
        command = "sync"
        args    = ["--dsn=tcp://127.0.0.1:9000", "--up="]
      }

      resources {
        cpu    = 256
        memory = 256
      }

      restart {
        attempts = 3
        delay    = "10s"
        mode     = "delay"
      }
    }

    # Schema Migrator Async
    task "schema-migrator-async" {
      driver = "podman"

      config {
        image = "docker.io/signoz/signoz-schema-migrator:${var.otelcol_tag}"
        network_mode = "host"
        command = "async"
        args    = ["--dsn=tcp://127.0.0.1:9000", "--up="]
      }

      resources {
        cpu    = 256
        memory = 256
      }

      restart {
        attempts = 5
        delay    = "30s"
        mode     = "delay"
      }
    }

    # SigNoz Backend
    task "signoz" {
      driver = "podman"

      config {
        image = "docker.io/signoz/signoz:${var.signoz_version}"
        network_mode = "host"

        command = "--config=/root/config/prometheus.yml"
        volumes = [
          "local/prometheus.yml:/root/config/prometheus.yml",
          # persistent state
          # selinux needs `sudo chcon -Rt container_file_t /data/clickhouse /data/clickhouse-logs /data/zookeeper /data/signoz`
          "/data/signoz:/var/lib/signoz"
        ]
      }

      env {
        SIGNOZ_JWT_SECRET                    = "supersecret-jwt-key-change-this-in-production"
        SIGNOZ_ALERTMANAGER_PROVIDER         = "signoz"
        SIGNOZ_TELEMETRYSTORE_CLICKHOUSE_DSN = "tcp://127.0.0.1:9000"
        SIGNOZ_SQLSTORE_SQLITE_PATH          = "/var/lib/signoz/signoz.db"
        STORAGE                              = "clickhouse"
        GODEBUG                              = "netdns=go"
        TELEMETRY_ENABLED                    = "true"
        DEPLOYMENT_TYPE                      = "nomad-standalone"
      }

      service {
          name         = "signoz-ui-sandbox"
          address_mode = "driver"
          port         = 8080

          check {
            type         = "http"
            path         = "/health"
            interval     = "10s"
            timeout      = "2s"
            address_mode = "driver"
            port         = 8080
          }
        }

      template {
        destination = "local/prometheus.yml"
        data = <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'signoz'
    static_configs:
      - targets: ['127.0.0.1:8080']
EOF
      }

      resources {
        cpu    = 2000
        memory = 4096
      }

      restart {
        attempts = 5
        delay    = "20s"
        mode     = "delay"
      }
    }

    # OTEL Collector
    task "otel-collector" {
      driver = "podman"

      config {
        image = "docker.io/signoz/signoz-otel-collector:${var.otelcol_tag}"
        network_mode = "host"
        command = "--config=/etc/otel-collector-config.yaml"
        volumes = [
          "local/otel-collector-config.yaml:/etc/otel-collector-config.yaml"
        ]
      }

      env {
        OTEL_RESOURCE_ATTRIBUTES        = "host.name=signoz-host,os.type=linux"
        LOW_CARDINAL_EXCEPTION_GROUPING = "false"
      }

      template {
        destination = "local/otel-collector-config.yaml"
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
    timeout: 10s

exporters:
  clickhousetraces:
    datasource: tcp://127.0.0.1:9000

  signozclickhousemetrics:
    dsn: tcp://127.0.0.1:9000

  clickhouselogsexporter:
    dsn: tcp://127.0.0.1:9000

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [clickhousetraces]

    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [signozclickhousemetrics]

    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [clickhouselogsexporter]
EOF
      }

      resources {
        cpu    = 1000
        memory = 1024
      }

      restart {
        attempts = 5
        delay    = "10s"
        mode     = "delay"
      }
    }
  }
}
