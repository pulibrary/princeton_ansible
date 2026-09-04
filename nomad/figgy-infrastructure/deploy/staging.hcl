variable "branch_or_sha" {
  type = string
  default = "main"
}
job "figgy-infrastructure-staging" {
  datacenters = ["dc1"]
  type = "service"
  node_pool = "staging"
  # Set a higher priority because this job only works on these boxes.
  priority = 60

  group "memcached" {
    count = 1
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
      port "memcached" {
        to = 11211
      }

      dns {
        servers = ["172.17.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    service {
      port = "memcached"
      tags = ["logging"]

      check {
        type = "tcp"
        port = "memcached"
        interval = "10s"
        timeout = "2s"
      }
    }

    task "memcached" {
      driver = "docker"

      config {
        image = "memcached:1.6-alpine"
        ports = ["memcached"]
        extra_hosts = ["host.containers.internal:host-gateway"]
        args = [
          # 512 MB of cache. It was 64 before, but y'know, we got ram.
          "--memory-limit=512",
          "--threads=4",
          # 4MB largest single thing cached.
          "--max-item-size=4M"
        ]
      }
      resources {
        cpu = 1000
        memory = 1024
      }
    }
  }

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
      name = "rabbitmq-staging"
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
      name = "rabbitmq-staging-management"
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
      source = "figgy-rabbitmq-staging-cluster"
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
        {{- with nomadVar "nomad/jobs/figgy-infrastructure-staging" -}}
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
        cluster_name = figgy-staging

        # Let's use Consul, we got it anyways.
        cluster_formation.peer_discovery_backend = consul
        cluster_formation.consul.host = host.containers.internal
        cluster_formation.consul.port = 8500
        cluster_formation.consul.scheme = http
        cluster_formation.consul.acl_token = {{ env "CONSUL_TOKEN" }}

        cluster_formation.consul.svc = rabbitmq-staging-peers
        cluster_formation.consul.svc_port = {{ env "NOMAD_PORT_amqp" }}
        cluster_formation.consul.svc_ttl = 30
        cluster_formation.consul.deregister_after = 90

        cluster_formation.consul.svc_addr_auto = true
        cluster_formation.consul.svc_addr_use_nodename = true
        cluster_formation.consul.use_longname = true

        cluster_formation.consul.lock_prefix = rabbitmq-staging
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

  # Three redises, watched by three sentinels.
  # Helpful docs: https://oneuptime.com/blog/post/2026-03-31-redis-sentinel-docker-compose/view, 
  # https://redis.io/docs/latest/operate/oss_and_stack/management/sentinel/
  group "redis" {
    count = 3

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
      port "redis" {
        static = 6379
      }
      port "sentinel" {
        static = 26379
      }

      dns {
        servers = ["172.17.0.1"]
      }
    }

    service {
      name = "figgy-redis-staging"
      port = "redis"
      tags = ["logging", "index-${NOMAD_ALLOC_INDEX}"]

      check {
        name = "redis-listener"
        type = "tcp"
        port = "redis"
        interval = "10s"
        timeout = "2s"
      }

      check {
        name = "redis-responding"
        type = "script"
        task = "redis"
        command = "redis-cli"
        args = ["-p", "6379", "ping"]
        interval = "30s"
        timeout = "10s"
      }
    }

    service {
      name = "figgy-redis-staging-sentinel"
      port = "sentinel"
      tags = ["logging"]

      check {
        name = "sentinel-listener"
        type = "tcp"
        port = "sentinel"
        interval = "10s"
        timeout = "2s"
      }

      check {
        name = "sentinel-responding"
        type = "script"
        task = "sentinel"
        command = "redis-cli"
        args = ["-p", "26379", "ping"]
        interval = "30s"
        timeout = "10s"
      }
    }

    volume "redis_data" {
      type = "host"
      source = "figgy-redis-staging-cluster"
      access_mode = "single-node-single-writer"
      attachment_mode = "file-system"
      sticky = false
    }

    task "redis" {
      driver = "docker"

      config {
        image = "redis:8.10-alpine"
        ports = ["redis"]
        command = "redis-server"
        args = ["/local/redis.conf"]
        extra_hosts = ["host.containers.internal:host-gateway"]
      }

      consul {}

      volume_mount {
        volume = "redis_data"
        destination = "/data"
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/figgy-infrastructure-staging" -}}
        REDISCLI_AUTH={{ .REDIS_PASSWORD }}
        {{- end -}}
        EOF
      }

      template {
        destination = "local/redis.conf"
        change_mode = "restart"
        perms = "0666"
        data = <<EOF
        port {{ env "NOMAD_PORT_redis" }}
        bind 0.0.0.0
        protected-mode no
        dir /data

        {{- with nomadVar "nomad/jobs/figgy-infrastructure-staging" }}
        requirepass {{ .REDIS_PASSWORD }}
        masterauth {{ .REDIS_PASSWORD }}
        {{- end }}

        appendonly yes
        appendfsync everysec
        save ""
        maxmemory-policy noeviction

        min-replicas-to-write 1
        min-replicas-max-lag 10

        replica-announce-ip {{ env "NOMAD_IP_redis" }}
        replica-announce-port {{ env "NOMAD_HOST_PORT_redis" }}
        {{- if ne (env "NOMAD_ALLOC_INDEX") "0" }}

        replicaof index-0.figgy-redis-staging.service.consul {{ env "NOMAD_HOST_PORT_redis" }}
        {{- end }}
        EOF
      }

      resources {
        cpu = 500
        memory = 512
      }
    }

    task "sentinel" {
      driver = "docker"

      config {
        image = "redis:8.10-alpine"
        ports = ["sentinel"]
        command = "redis-sentinel"
        args = ["/local/sentinel.conf"]
        extra_hosts = ["host.containers.internal:host-gateway"]
      }

      consul {}

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/figgy-infrastructure-staging" -}}
        REDISCLI_AUTH={{ .REDIS_PASSWORD }}
        {{- end -}}
        EOF
      }

      template {
        destination = "local/sentinel.conf"
        change_mode = "restart"
        perms = "0666"
        data = <<EOF
        port {{ env "NOMAD_PORT_sentinel" }}
        bind 0.0.0.0
        protected-mode no
        dir /local

        sentinel announce-ip {{ env "NOMAD_IP_sentinel" }}
        sentinel announce-port {{ env "NOMAD_HOST_PORT_sentinel" }}

        sentinel resolve-hostnames yes
        sentinel monitor figgy-staging figgy-redis-staging.service.consul {{ env "NOMAD_HOST_PORT_redis" }} 2
        sentinel down-after-milliseconds figgy-staging 5000
        sentinel failover-timeout figgy-staging 30000
        sentinel parallel-syncs figgy-staging 1

        {{- with nomadVar "nomad/jobs/figgy-infrastructure-staging" }}
        requirepass {{ .REDIS_PASSWORD }}
        sentinel sentinel-pass {{ .REDIS_PASSWORD }}
        sentinel auth-pass figgy-staging {{ .REDIS_PASSWORD }}
        {{- end }}
        EOF
      }

      resources {
        cpu = 100
        memory = 64
      }
    }
  }
}
