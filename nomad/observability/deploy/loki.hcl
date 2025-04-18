variable "branch_or_sha" {
  type = string
  default = "main"
}
job "loki" {
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "staging"
  update {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "10s"
    healthy_deadline  = "3m"
    progress_deadline = "5m"
  }
  group "loki" {
    count = 1
    restart {
      attempts = 3
      interval = "5m"
      delay    = "25s"
      mode     = "delay"
    }
    network {
      port "loki" {
        static = 3100
      }
    }
    volume "loki" {
      type      = "host"
      read_only = false
      source    = "loki"
    }
    service {
      name = "loki"
        port = "loki"
        check {
          name     = "Loki healthcheck"
            port     = "loki"
            type     = "http"
            path     = "/ready"
            interval = "20s"
            timeout  = "5s"
            check_restart {
              limit           = 3
                grace           = "60s"
                ignore_warnings = false
            }
        }
    }
    task "loki" {
      driver = "podman"
      user = "root"
      config {
        image = "grafana/loki:3.2.1"
        args = [
          "-config.file",
          "local/loki/local-config.yaml",
        ]
        ports = ["loki"]
      }
      volume_mount {
        volume      = "loki"
        destination = "/loki"
        read_only   = false
      }
      template {
        data = <<EOH
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096
  log_level: debug
  grpc_server_max_concurrent_streams: 1000

common:
  instance_addr: 127.0.0.1
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory
query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100
storage_config:
  filesystem:
    directory: /loki/chunks
  tsdb_shipper: 
    active_index_directory: /loki/tsdb-index
    cache_location: /loki/tsdb-cache
compactor:
  working_directory: /loki/retention
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
  retention_delete_worker_count: 150
  delete_request_store: filesystem
limits_config:
  retention_period: 360h
schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

pattern_ingester:
  enabled: true
  metric_aggregation:
    enabled: true
    loki_address: localhost:3100

ruler:
  alertmanager_url: http://localhost:9093

frontend:
  encoding: protobuf
EOH
        destination = "local/loki/local-config.yaml"
      }
      resources {
        cpu    = 512
        memory = 256
      }
    }
  }
}
