variable "branch_or_sha" {
  type = string
  default = "main"
}
job "redis-staging" {
  datacenters = ["dc1"]
  type = "service"
  node_pool = "staging"
  # Set a higher priority because this job only works on boxes with storage provisioned, so it needs to push other jobs off them.
  priority = 60

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
      name = "redis-staging"
      port = "redis"
      tags = ["logging", "index-${NOMAD_ALLOC_INDEX}"]

      check {
        type = "tcp"
        port = "redis"
        interval = "10s"
        timeout = "2s"
      }

      check {
        type = "script"
        task = "redis"
        command = "redis-cli"
        args = ["-p", "6379", "ping"]
        interval = "30s"
        timeout = "10s"
      }
    }

    service {
      name = "redis-staging-sentinel"
      port = "sentinel"
      tags = ["logging"]

      check {
        type = "tcp"
        port = "sentinel"
        interval = "10s"
        timeout = "2s"
      }

      check {
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
      source = "redis-staging-cluster"
      access_mode = "single-node-single-writer"
      attachment_mode = "file-system"
      sticky = false
    }

    task "redis" {
      driver = "docker"
      user = "999:999"

      config {
        image = "redis:8.10-alpine"
        ports = ["redis"]
        entrypoint = ["redis-server"]
        # Anything that might change needs to be in args, since the config gets overridden.
        args = [
          "/data/redis/redis.conf",
          "--masterauth", "${REDIS_PASSWORD}",
          "--replica-announce-ip", "${NOMAD_IP_redis}",
          "--replica-announce-port", "${NOMAD_HOST_PORT_redis}",
        ]
        extra_hosts = ["host.containers.internal:host-gateway"]
      }

      consul {}

      volume_mount {
        volume = "redis_data"
        destination = "/data"
      }

      template {
        destination = "local/redis-users.acl"
        change_mode = "restart"
        uid = 1000999
        gid = 1000999
        perms = "0640"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/redis-staging" }}
        user default on >{{ .REDIS_PASSWORD }} ~* &* +@all
        {{- end }}
        EOF
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/redis-staging" -}}
        REDIS_PASSWORD={{ .REDIS_PASSWORD }}
        REDISCLI_AUTH={{ .REDIS_PASSWORD }}
        {{- end -}}
        EOF
      }

      resources {
        cpu = 500
        memory = 512
      }
    }

    # Redis & Sentinel both overwrite their .conf files constantly to keep state on the cluster. We'll give it some startup values, then leave it alone after that.
    task "seed-config" {
      driver = "docker"
      user = "999:999"

      lifecycle {
        hook = "prestart"
        sidecar = false
      }

      consul {}

      config {
        image = "redis:8.10-alpine"
        entrypoint = ["/bin/sh", "-c"]
        args = ["mkdir -p /data/redis /data/sentinel && { [ -f /data/redis/redis.conf ] || cp /local/redis.conf /data/redis/redis.conf; } && { [ -f /data/sentinel/sentinel.conf ] || cp /local/sentinel.conf /data/sentinel/sentinel.conf; }"]
      }

      volume_mount {
        volume = "redis_data"
        destination = "/data"
      }

      template {
        destination = "local/redis.conf"
        uid = 1000999
        gid = 1000999
        perms = "0640"
        data = <<EOF
        bind 0.0.0.0
        protected-mode no
        dir /data
        aclfile /local/redis-users.acl

        appendonly yes
        appendfsync everysec
        save ""
        maxmemory-policy noeviction

        min-replicas-to-write 1
        min-replicas-max-lag 10

        {{- if ne (env "NOMAD_ALLOC_INDEX") "0" }}

        {{- with service "index-0.redis-staging|any" }}
        {{- with index . 0 }}
        replicaof {{ .Address }} {{ .Port }}
        {{- end }}
        {{- end }}
        {{- end }}
        EOF
      }

      template {
        destination = "local/sentinel.conf"
        uid = 1000999
        gid = 1000999
        perms = "0640"
        data = <<EOF
        sentinel resolve-hostnames yes
        {{- with service "index-0.redis-staging|any" }}
        {{- with index . 0 }}
        sentinel monitor redis-staging {{ .Address }} {{ .Port }} 2
        {{- end }}
        {{- end }}
        bind 0.0.0.0
        protected-mode no
        dir /data/sentinel

        sentinel down-after-milliseconds redis-staging 5000
        sentinel failover-timeout redis-staging 30000
        sentinel parallel-syncs redis-staging 1
        aclfile /local/sentinel-users.acl
        EOF
      }

      resources {
        cpu = 50
        memory = 32
      }
    }

    task "sentinel" {
      driver = "docker"
      user = "999:999"

      config {
        image = "redis:8.10-alpine"
        ports = ["sentinel"]
        command = "redis-sentinel"
        # Anything that might change needs to be in args, since the config gets overridden.
        args = [
          "/data/sentinel/sentinel.conf",
          "--sentinel", "auth-pass", "redis-staging", "${REDIS_PASSWORD}",
          "--sentinel", "sentinel-pass", "${REDIS_PASSWORD}",
          "--sentinel", "announce-ip", "${NOMAD_IP_sentinel}",
          "--sentinel", "announce-port", "${NOMAD_HOST_PORT_sentinel}",
        ]
        extra_hosts = ["host.containers.internal:host-gateway"]
      }

      consul {}

      volume_mount {
        volume = "redis_data"
        destination = "/data"
      }

      template {
        destination = "local/sentinel-users.acl"
        change_mode = "restart"
        uid = 1000999
        gid = 1000999
        perms = "0640"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/redis-staging" }}
        user default on >{{ .REDIS_PASSWORD }} ~* &* +@all
        {{- end }}
        EOF
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/redis-staging" -}}
        REDIS_PASSWORD={{ .REDIS_PASSWORD }}
        REDISCLI_AUTH={{ .REDIS_PASSWORD }}
        {{- end -}}
        EOF
      }

      resources {
        cpu = 100
        memory = 64
      }
    }
  }
}
