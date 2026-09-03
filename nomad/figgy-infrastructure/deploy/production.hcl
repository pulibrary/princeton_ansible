variable "branch_or_sha" {
  type = string
  default = "main"
}
job "figgy-infrastructure-production" {
  datacenters = ["dc1"]
  type = "service"
  node_pool = "production"
  # Set a higher priority because this job only works on these boxes.
  priority = 60

  group "rabbitmq" {
    count = 3

    # Remove from consul, wait 10s, then shut down.
    shutdown_delay = "10s"

    update {
      max_parallel = 1
      health_check = "checks"
      min_healthy_time = "30s"
      healthy_deadline = "5m"
      progress_deadline = "15m"
      auto_revert = true
    }

    migrate {
      max_parallel = 1
      health_check = "checks"
      min_healthy_time = "30s"
    }

    network {
      port "amqp" {
        static = 5672
      }
      port "management" {
        static = 15672
      }
      # Yay erlang. Change this so we can run other erlang stuff if we want.
      port "epmd" {
        static = 24369
      }
      # Port for rabbit chatter.
      port "dist" {
        static = 25672
      }

      dns {
        servers = ["172.17.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    service {
      name = "rabbitmq-production"
      port = "amqp"
      tags = ["logging"]

      check {
        name = "amqp-listener"
        type = "tcp"
        port = "amqp"
        interval = "10s"
        timeout = "2s"
      }

      check {
        name = "rabbitmq-running"
        type = "script"
        task = "rabbitmq"
        command = "rabbitmq-diagnostics"
        args = ["-q", "check_running"]
        interval = "30s"
        timeout = "20s"
      }
    }

    service {
      name = "rabbitmq-production-management"
      port = "management"

      check {
        name = "management-ui"
        type = "http"
        port = "management"
        path = "/"
        interval = "30s"
        timeout = "5s"
      }
    }

    volume "rabbitmq_data" {
      type = "host"
      source = "figgy-rabbitmq-production-cluster"
      access_mode = "single-node-single-writer"
      attachment_mode = "file-system"
      sticky = false
    }

    task "rabbitmq" {
      driver = "docker"

      # Get a task identity, we give it permissions to update consul services for RabbitMQ clustering in the playbook.
      consul {}

      config {
        image = "rabbitmq:4.3-management"
        hostname = "${node.unique.name}.lib.princeton.edu"
        ports = ["amqp", "management", "epmd", "dist"]

        volumes = [
          "local/rabbitmq.conf:/etc/rabbitmq/conf.d/20-cluster.conf",
          "local/enabled_plugins:/etc/rabbitmq/enabled_plugins",
        ]

        extra_hosts = ["host.containers.internal:host-gateway"]
      }

      volume_mount {
        volume = "rabbitmq_data"
        destination = "/var/lib/rabbitmq"
      }

      env {
        RABBITMQ_USE_LONGNAME = "true"
        RABBITMQ_NODENAME = "rabbit@${node.unique.name}.lib.princeton.edu"
        RABBITMQ_DIST_PORT = "${NOMAD_PORT_dist}"
        ERL_EPMD_PORT = "${NOMAD_PORT_epmd}"
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
{{- with nomadVar "nomad/jobs/figgy-infrastructure-production" -}}
RABBITMQ_DEFAULT_USER={{ .RABBITMQ_USER }}
RABBITMQ_DEFAULT_PASS={{ .RABBITMQ_PASSWORD }}
RABBITMQ_ERLANG_COOKIE={{ .RABBITMQ_ERLANG_COOKIE }}
{{- end -}}
EOF
      }

      # Consul clustering docs: https://www.rabbitmq.com/docs/cluster-formation#configuration-3
      template {
        destination = "local/rabbitmq.conf"
        change_mode = "restart"
        data = <<EOF
cluster_name = figgy-production

# Let's use Consul, we got it anyways.
cluster_formation.peer_discovery_backend = consul
cluster_formation.consul.host = host.containers.internal
cluster_formation.consul.port = 8500
cluster_formation.consul.scheme = http
cluster_formation.consul.acl_token = {{ env "CONSUL_TOKEN" }}

cluster_formation.consul.svc = rabbitmq-production-peers
cluster_formation.consul.svc_port = {{ env "NOMAD_PORT_amqp" }}
cluster_formation.consul.svc_ttl = 30
cluster_formation.consul.deregister_after = 90

cluster_formation.consul.svc_addr_auto = true
cluster_formation.consul.svc_addr_use_nodename = true
cluster_formation.consul.use_longname = true

cluster_formation.consul.lock_prefix = rabbitmq-production
cluster_formation.consul.lock_wait_time = 300

# Make the default queue a quorum, so it can survive one node dying.
default_queue_type = quorum

management.tcp.port = {{ env "NOMAD_PORT_management" }}
EOF
      }

      template {
        destination = "local/enabled_plugins"
        change_mode = "restart"
        data = "[rabbitmq_management,rabbitmq_prometheus,rabbitmq_peer_discovery_consul].\n"
      }

      resources {
        cpu = 1000
        memory = 512
      }
    }
  }
}
