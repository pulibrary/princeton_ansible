variable "branch_or_sha" {
  type = string
  default = "main"
}
job "log-shipping" {
  datacenters = ["dc1"]
  # system job, runs on all nodes
  type = "system" 
  node_pool = "staging"
  update {
    min_healthy_time = "10s"
    healthy_deadline = "5m"
    progress_deadline = "10m"
    auto_revert = true
  }
  group "vector" {
    count = 1
    restart {
      attempts = 3
      interval = "10m"
      delay = "30s"
      mode = "fail"
    }
    network {
      port "api" {
        to = 8686
      }
      port "metrics" {
        to = 9090
      }
    }
    service {
      port = "metrics"
      tags = ["metrics"]
    }
    volume "podman-socket" {
      type = "host"
      source = "podman-socket"
      read_only = true
    }
    ephemeral_disk {
      size    = 500
      sticky  = true
    }
    task "vector" {
      driver = "podman"
      user = "root"
      config {
        image = "docker.io/timberio/vector:0.46.X-alpine"
        ports = ["api", "metrics"]
        selinux_opts = [
          "disable"
        ]
      }
      volume_mount {
        volume = "podman-socket"
        destination = "/var/run/podman/podman.sock"
        read_only = true
      }
      env {
        VECTOR_CONFIG = "local/vector.yml"
        VECTOR_REQUIRE_HEALTHY = "true"
      }
      resources {
        cpu    = 500
        memory = 256
      }
      template {
        destination = "local/vector.yml"
        change_mode   = "signal"
        change_signal = "SIGHUP"
        # overriding the delimiters to [[ ]] to avoid conflicts with Vector's native templating, which also uses {{ }}
        left_delimiter = "[["
        right_delimiter = "]]"
        data=<<EOH
          data_dir: "alloc/data/vector/"
          api:
            enabled: false
          # --- Sources ---
          sources:
            logs:
              type: "docker_logs"
              docker_host: "unix:///var/run/podman/podman.sock"
            # Added source for Vector's internal metrics
            internal_metrics:
              type: "internal_metrics"
          # --- Sinks ---
          sinks:
            out:
              type: "console"
              inputs: [ "logs" ]
              encoding:
                codec: "json"
            loki:
              type: "loki"
              inputs: ["logs"]
              endpoint: "http://[[ range service "loki" ]][[ .Address ]]:[[ .Port ]][[ end ]]"
              encoding:
                codec: "json"
              healthcheck:
                enabled: true
              buffer:
                type: "disk"
                when_full: "block"
                max_size: 1073741824
              request:
                retry_attempts: 5
                retry_initial_backoff_secs: 1
                retry_max_duration_secs: 60
              labels:
                job_name: "{{ label.com.hashicorp.nomad.job_name }}"
                task_name: "{{ label.com.hashicorp.nomad.task_name }}"
                group_name: "{{ label.com.hashicorp.nomad.task_group_name }}"
                namespace: "{{ label.com.hashicorp.nomad.namespace }}"
                node_name: "{{ label.com.hashicorp.nomad.node_name }}"
              remove_label_fields: true
            prometheus_exporter:
              type: "prometheus_exporter"
              inputs: ["internal_metrics"]
              address: "0.0.0.0:9090"
              namespace: "vector"
        EOH
      }
      service {
        check {
          port     = "api"
          type     = "http"
          path     = "/health"
          interval = "30s"
          timeout  = "5s"
        }
      }
      kill_timeout = "30s"
    }
  }
}
