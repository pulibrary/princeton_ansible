variable "branch_or_sha" {
  type = string
  default = "main"
}
job "log-shipping" {
  datacenters = ["dc1"]
  type = "system"
  node_pool   = "all"
  priority = 60
  group "log-shipping" {
    count = 1
        consul {}

    network {
      dns {
        servers = ["10.88.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }
    restart {
      attempts = 2
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }
    ephemeral_disk {
      size = 300
    }
    task "nomad-forwarder" {
      driver = "podman"
      env {
        VERBOSE    = 4
        LOG_TAG    = "logging"
        LOG_FILE   = "${NOMAD_ALLOC_DIR}/nomad-logs.log"
        # this is the IP of the podman interface
        NOMAD_ADDR = "http://10.88.0.1:4646"
      }
      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/log-shipping" -}}
        NOMAD_TOKEN = {{ .NOMAD_TOKEN }}
        {{- end -}}
        EOF
      }
      config {
        image = "docker.io/sofixa/nomad_follower:latest"
      }
      # resource limits are a good idea because you don't want your log collection to consume all resources available
      resources {
        cpu    = 100
        memory = 512
      }
    }
    task "alloy" {
      driver = "podman"
      config {
        image = "docker.io/grafana/alloy:latest"
        args = [
          "run",
          "local/config.alloy",
        ]
      }
      template {
        data        = <<EOH
          logging {
              level = "debug"
              format = "logfmt"
          }
          local.file_match "logs" {
              path_targets = [{
                  __address__ = "localhost",
                  __path__    = "{{ env "NOMAD_ALLOC_DIR" }}//nomad-logs.log",
                  job         = "nomad",
              }]
          }

          loki.process "logs" {
            forward_to = [loki.write.destination.receiver]
            stage.json {
              expressions = {
                  alloc_id     = "alloc_id",
                  data         = "data",
                  job_name     = "job_name",
                  message      = "message",
                  node_name    = "node_name",
                  service_name = "service_name",
                  task_name    = "task_name",
                }
              }
              stage.labels {
                  values = {
                      job_name     = null,
                      alloc_id     = null,
                      node_name    = null,
                      service_name = null,
                      task_name = null,
                  }
                }
              }
              loki.source.file "logs" {
                  targets               = local.file_match.logs.targets
                  forward_to            = [loki.process.logs.receiver]
                  legacy_positions_file = "local/positions.yaml"
              }

              loki.write "destination" {
                endpoint {
                    url = "http://loki.service.consul:3100/loki/api/v1/push"
                }
              }

              EOH
        destination = "local/config.alloy"
      }
      resources {
        cpu    = 100
        memory = 512
      }
    }
  }
}
