variable "branch_or_sha" {
  type = string
  default = "main"
}
job "figgy-infrastructure-staging" {
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "staging"
  # Set a higher priority because this job only works on this box.
  priority = 60

  group "rabbitmq" {
    count = 1

    network {
      port "rabbitmq" {
        static = 5672
      }
      port "rabbitmq_management" {
        static = 15672
      }
      dns {
        servers = ["172.17.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    service {
      port = "rabbitmq"
    }

    volume "rabbitmq_data" {
      type   = "host"
      source = "figgy-rabbitmq-staging"
      access_mode     = "single-node-single-writer"
      attachment_mode = "file-system"
      sticky = true
    }

    task "rabbitmq" {
      driver = "docker"

      config {
        image = "rabbitmq:4.3-management"
        hostname = "${attr.unique.hostname}"
        ports = ["rabbitmq", "rabbitmq_management"]
      }

      volume_mount {
        volume      = "rabbitmq_data"
        destination = "/var/lib//rabbitmq"
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/figgy-infrastructure-staging" -}}
        RABBITMQ_DEFAULT_USER = {{ .RABBITMQ_USER }}
        RABBITMQ_DEFAULT_PASS = {{ .RABBITMQ_PASSWORD }}
        {{- end -}}
        EOF
      }

      resources {
        cpu    = 2000
        memory = 2000
      }
    }
  }
}
