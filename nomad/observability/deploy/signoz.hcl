variable "branch_or_sha" {
  type = string
  default = "main"
}
# This automatically runs a signoz collector on every client and binds a receive
# interface on Podman's loopback network.
job "signoz-collector" {
  # Set priority over 50 - it's important we can send traces.
  priority = 60
  region = "global"
  datacenters = ["dc1"]
  type = "system"
  node_pool = "all"
  group "otel-agent" {
    count = 1
    network {
      port "otlp_receive" { to = 4317 }
      # Add the consul DNS loopback, so we can use consul queries.
      dns {
        servers = ["10.88.0.1", "128.112.129.209"]
      }
    }
    service {
      port     = "otlp_receive"
      tags     = ["grpc"]
    }
    task "otel" {
      driver = "podman"

      config {
        image = "docker.io/signoz/signoz-otel-collector:v0.128.2"

        args = [
          "--config=local/config/otel-collector-config.yaml"
        ]

        ports = [
          "otlp_receive"
        ]
      }

      resources {
        cpu    = 500
        memory = 2048
      }

      template {
        data = <<EOF
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: "0.0.0.0:4317"
processors:
  resource:
    attributes:
      - key: host.name
        value: "{{ env "NOMAD_NODE_NAME" }}"
        action: upsert
      - key: service.version
        value: "{{ env "NOMAD_NODE_POOL" }}"
        action: upsert
  batch:
    timeout: 10s
    send_batch_size: 1024
    send_batch_max_size: 2048
  memory_limiter:
    limit_mib: 512
    spike_limit_mib: 128
    check_interval: "1s"
exporters:
  otlp:
    endpoint: "http://sandbox-signoz1.lib.princeton.edu:4317"
    tls:
      insecure: true
    sending_queue:
      num_consumers: 10
      queue_size: 5000
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 30s
      max_elapsed_time: 300s
service:
  extensions: []
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, resource, batch]
      exporters: [otlp]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, resource, batch]
      exporters: [otlp]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, resource, batch]
      exporters: [otlp]
  telemetry:
    metrics:
      readers:
        - pull:
            exporter:
              prometheus:
                host: 127.0.0.1
                port: 9998
EOF

        destination = "local/config/otel-collector-config.yaml"
      }
    }
  }
}
