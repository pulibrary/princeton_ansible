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

    constraint {
      attribute = "${node.unique.name}"
      operator = "set_contains_any"
      value = "nomad-client-staging1,nomad-client-staging3,nomad-client-staging4"
    }

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

    restart {
      attempts = 10
      delay = "15s"
      render_templates = true
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
        command = "sh"
        args = ["-c", "redis-cli info replication | grep -qE 'role:master|master_link_status:up'"]
        interval = "10s"
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
      source = "redis"
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
          "/alloc/data/redis.conf",
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
        memory = 2048
      }
    }

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
        entrypoint = ["/bin/sh", "/local/seed.sh"]
      }

      volume_mount {
        volume = "redis_data"
        destination = "/data"
      }

      template {
        destination = "local/seed.sh"
        uid = 1000999
        gid = 1000999
        perms = "0640"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/redis-staging" }}
        export REDISCLI_AUTH='{{ .REDIS_PASSWORD }}'
        {{- end }}
        # Find the running sentinels.
        SENTINELS="{{ range service "redis-staging-sentinel" }}{{ .Address }} {{ end }}"
        # Ask them who the primary is.
        for s in $SENTINELS; do
          LEADER=$(redis-cli -h $s -p 26379 SENTINEL get-master-addr-by-name redis-staging | head -n 1)
          [ -n "$LEADER" ] && break
        done
        # Brand new cluster, so the first one is the primary.
        if [ -z "$SENTINELS" ] && [ "$NOMAD_ALLOC_INDEX" = 0 ]; then
          cp /local/redis.conf /alloc/data/redis.conf
          LEADER=$NOMAD_IP_redis
        # Someone else is primary, so copy from them.
        elif [ -n "$LEADER" ] && [ "$LEADER" != "$NOMAD_IP_redis" ]; then
          { cat /local/redis.conf; echo "replicaof $LEADER 6379"; } > /alloc/data/redis.conf
          # If the primary is up, make the sentinels relearn the cluster.
          redis-cli -h $LEADER ping | grep -q PONG && for s in $SENTINELS; do redis-cli -h $s -p 26379 SENTINEL RESET redis-staging; done
        # We were the primary and still have our data, so stay primary.
        elif [ "$LEADER" = "$NOMAD_IP_redis" ] && [ -d /data/appendonlydir ]; then
          cp /local/redis.conf /alloc/data/redis.conf
        # Not safe to start yet, so try again.
        else
          exit 1
        fi
        # Point our sentinel at the primary.
        { echo "sentinel monitor redis-staging $LEADER 6379 2"; cat /local/sentinel.conf; } > /alloc/data/sentinel.conf
        EOF
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

        # Don't do anything unless it's replicated.
        min-replicas-to-write 1
        min-replicas-max-lag 10
        EOF
      }

      template {
        destination = "local/sentinel.conf"
        uid = 1000999
        gid = 1000999
        perms = "0640"
        data = <<EOF
        bind 0.0.0.0
        protected-mode no
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

    task "forget" {
      driver = "docker"
      user = "999:999"

      lifecycle {
        hook = "poststop"
      }

      consul {}

      config {
        image = "redis:8.10-alpine"
        entrypoint = ["/bin/sh", "/local/forget.sh"]
      }

      template {
        destination = "local/forget.sh"
        uid = 1000999
        gid = 1000999
        perms = "0640"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/redis-staging" }}
        export REDISCLI_AUTH='{{ .REDIS_PASSWORD }}'
        {{- end }}
        # Find the running sentinels.
        SENTINELS="{{ range service "redis-staging-sentinel" }}{{ .Address }} {{ end }}"
        # Wait up to a minute for a new primary.
        for i in $(seq 30); do
          LEADER=""
          for s in $SENTINELS; do
            LEADER=$(redis-cli -h $s -p 26379 SENTINEL get-master-addr-by-name redis-staging | head -n 1)
            FLAGS=$(redis-cli -h $s -p 26379 SENTINEL master redis-staging | sed -n '/^flags$/{n;p;}')
            [ -n "$LEADER" ] && break
          done
          # No sentinels left, nothing to clean up.
          [ -z "$LEADER" ] && exit 0
          # Once another primary is healthy, make the sentinels forget us.
          if [ "$LEADER" != "$NOMAD_IP_redis" ] && [ "$FLAGS" = master ]; then
            for s in $SENTINELS; do redis-cli -h $s -p 26379 SENTINEL RESET redis-staging; done
            exit 0
          fi
          sleep 2
        done
        EOF
      }

      resources {
        cpu = 100
        memory = 64
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
          "/alloc/data/sentinel.conf",
          "--sentinel", "auth-pass", "redis-staging", "${REDIS_PASSWORD}",
          "--sentinel", "sentinel-pass", "${REDIS_PASSWORD}",
          "--sentinel", "announce-ip", "${NOMAD_IP_sentinel}",
          "--sentinel", "announce-port", "${NOMAD_HOST_PORT_sentinel}",
        ]
        extra_hosts = ["host.containers.internal:host-gateway"]
      }

      consul {}

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
