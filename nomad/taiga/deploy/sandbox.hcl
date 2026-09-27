variable "branch_or_sha" {
  type    = string
  default = "main"
}

variable "taiga_back_version" {
  type    = string
  default = "latest"
}

# robrotheram/taiga-back-openid and robrotheram/taiga-front-openid are
# taigaio/taiga-back and taigaio/taiga-front rebuilt with the
# taiga-contrib-openid-auth plugin baked in. taiga-async stays on the
# stock taigaio/taiga-back image below, since it only runs celery tasks
# and never serves the auth endpoints the plugin adds.
variable "taiga_back_openid_version" {
  type    = string
  default = "latest"
}

variable "taiga_front_openid_version" {
  type    = string
  default = "latest"
}

variable "taiga_events_version" {
  type    = string
  default = "latest"
}

variable "taiga_protected_version" {
  type    = string
  default = "latest"
}

job "taiga-sandbox" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "sandbox"

  group "taiga" {
    count = 1

    # Required for Nomad's Workload Identity model to authorize this
    # group to register its service with Consul (see nomad/zookeeper and
    # nomad/solr, which need it for the same reason). Without it, nothing
    # gets registered — confirmed via `consul catalog services` returning
    # empty, not just missing "taiga-sandbox".
    consul {}

    shutdown_delay = "10s"

    # taiga-back, taiga-async, and the gateway all need to see the same
    # static/media files, so they share one sticky volume via subdirectories.
    volume "data" {
      type            = "host"
      source          = "taiga-sandbox"
      access_mode     = "single-node-single-writer"
      attachment_mode = "file-system"
      sticky          = true
    }

    update {
      max_parallel      = 1
      health_check      = "checks"
      min_healthy_time  = "20s"
      healthy_deadline  = "10m"
      progress_deadline = "15m"
      auto_revert       = true
    }

    restart {
      attempts = 5
      interval = "15m"
      delay    = "15s"
      mode     = "delay"
    }

    reschedule {
      delay          = "30s"
      delay_function = "exponential"
      max_delay      = "5m"
      unlimited      = true
    }

    network {
      # Mode defaults to "bridge" (Nomad's CNI networking), which is what
      # every other docker-driver job in this repo relies on implicitly.
      # This cluster's Docker daemon runs with userns-remap enabled, and
      # Docker refuses "--network=host" for any container while
      # userns-remap is on, so "host" mode isn't an option here (it's
      # only what the old podman-driver version of this job used). All
      # tasks in a group still share one network namespace under bridge
      # mode, so sibling tasks still reach each other over 127.0.0.1.

      # Front, back, events, protected, and rabbitmq bind ports that are
      # hardcoded inside their upstream images, so they're reserved as
      # static with no "to", which maps the host port straight through to
      # the same container port. Only the gateway's listen port is ours
      # to choose, so it's left dynamic (Nomad still registers it with
      # Consul for nginxplus).
      port "http" {}
      port "front" {
        static = 80
      }
      port "back" {
        static = 8000
      }
      port "events" {
        static = 8888
      }
      port "protected" {
        static = 8003
      }
      port "rabbitmq" {
        static = 5672
      }

      dns {
        servers = ["172.17.0.1", "128.112.129.209", "128.112.129.7"]
      }
    }

    service {
      name = "taiga-sandbox"
      port = "http"
      tags = ["logging"]

      check {
        type     = "http"
        port     = "http"
        path     = "/"
        interval = "15s"
        timeout  = "5s"

        check_restart {
          limit = 5
          grace = "5m"
        }
      }
    }

    task "rabbitmq" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      # A single broker handles both celery's task queue and the events
      # websocket fan-out; Taiga's own consumers create the queues they
      # need, so there's no need to run two separate brokers per-service
      # like the upstream docker-compose does.
      config {
        image        = "docker.io/library/rabbitmq:3.13.6-management-alpine"
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/rabbitmq.env"
        env         = true
        change_mode = "restart"

        data = <<-EOF
        {{- with nomadVar "nomad/jobs/taiga-sandbox" }}
        RABBITMQ_DEFAULT_USER={{ .RABBITMQ_USER }}
        RABBITMQ_DEFAULT_PASS={{ .RABBITMQ_PASS }}
        RABBITMQ_DEFAULT_VHOST={{ .RABBITMQ_VHOST }}
        RABBITMQ_NODE_IP_ADDRESS=127.0.0.1
        RABBITMQ_MNESIA_BASE=/persistence/rabbitmq/mnesia
        RABBITMQ_LOG_BASE=/persistence/rabbitmq/log
        {{- end }}
        EOF
      }

      volume_mount {
        volume      = "data"
        destination = "/persistence"
      }

      resources {
        cpu    = 500
        memory = 768
      }
    }

    task "await-infrastructure" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        image        = "docker.io/library/busybox:1.37"
        entrypoint   = ["/bin/sh", "-c"]
        args = [
          "until nc -z -w 2 127.0.0.1 5672; do echo 'waiting for RabbitMQ'; sleep 2; done; until nc -z -w 2 sandbox-postgresql1.lib.princeton.edu 5432; do echo 'waiting for PostgreSQL'; sleep 2; done",
        ]
      }

      resources {
        cpu    = 50
        memory = 32
      }
    }

    task "taiga-back" {
      driver = "docker"

      config {
        image        = "docker.io/robrotheram/taiga-back-openid:${var.taiga_back_openid_version}"
        entrypoint   = ["/bin/bash", "-c"]
        # taiga-back's image ships /taiga-back/static and /taiga-back/media
        # as plain directories; swap them for symlinks into the sticky
        # volume before handing off to the image's own entrypoint.
        args = [
          "mkdir -p /persistence/static /persistence/media && rm -rf /taiga-back/static /taiga-back/media && ln -s /persistence/static /taiga-back/static && ln -s /persistence/media /taiga-back/media && exec /taiga-back/docker/entrypoint.sh",
        ]
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/taiga-back.env"
        env         = true
        change_mode = "restart"

        data = <<-EOF
        {{- with nomadVar "nomad/jobs/taiga-sandbox" }}
        POSTGRES_DB={{ .DB_NAME }}
        POSTGRES_USER={{ .DB_USER }}
        POSTGRES_PASSWORD={{ .DB_PASSWORD }}
        POSTGRES_HOST={{ .DB_HOST }}
        TAIGA_SECRET_KEY={{ .SECRET_KEY }}
        TAIGA_SITES_SCHEME=https
        TAIGA_SITES_DOMAIN={{ .DOMAIN_NAME }}
        TAIGA_SUBPATH=
        EMAIL_BACKEND=console
        DEFAULT_FROM_EMAIL={{ .EMAIL_DEFAULT_FROM }}
        EMAIL_USE_TLS=False
        EMAIL_USE_SSL=False
        RABBITMQ_USER={{ .RABBITMQ_USER }}
        RABBITMQ_PASS={{ .RABBITMQ_PASS }}
        ENABLE_TELEMETRY=False
        # taiga-contrib-openid-auth (baked into this image). taiga-back
        # only needs the token-exchange settings; OPENID_URL and
        # OPENID_NAME are consumed by taiga-front below instead.
        ENABLE_OPENID=True
        OPENID_USER_URL={{ .OPENID_USER_URL }}
        OPENID_TOKEN_URL={{ .OPENID_TOKEN_URL }}
        OPENID_CLIENT_ID={{ .OPENID_CLIENT_ID }}
        OPENID_CLIENT_SECRET={{ .OPENID_CLIENT_SECRET }}
        # Must match the frontend plugin's authorize-request scope
        # (front/coffee/openid-auth.coffee hardcodes "User.Read" with no
        # env override), since the token exchange has to ask for a scope
        # the user actually consented to. "User.Read" is a valid Graph
        # scope and still works against graph.microsoft.com/oidc/userinfo.
        OPENID_SCOPE=User.Read
        {{- end }}
        EOF
      }

      volume_mount {
        volume      = "data"
        destination = "/persistence"
      }

      resources {
        cpu    = 1000
        memory = 1024
      }
    }

    task "taiga-async" {
      driver = "docker"

      config {
        image        = "docker.io/taigaio/taiga-back:${var.taiga_back_version}"
        entrypoint   = ["/bin/bash", "-c"]
        args = [
          "mkdir -p /persistence/static /persistence/media && rm -rf /taiga-back/static /taiga-back/media && ln -s /persistence/static /taiga-back/static && ln -s /persistence/media /taiga-back/media && exec /taiga-back/docker/async_entrypoint.sh",
        ]
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/taiga-async.env"
        env         = true
        change_mode = "restart"

        data = <<-EOF
        {{- with nomadVar "nomad/jobs/taiga-sandbox" }}
        POSTGRES_DB={{ .DB_NAME }}
        POSTGRES_USER={{ .DB_USER }}
        POSTGRES_PASSWORD={{ .DB_PASSWORD }}
        POSTGRES_HOST={{ .DB_HOST }}
        TAIGA_SECRET_KEY={{ .SECRET_KEY }}
        TAIGA_SITES_SCHEME=https
        TAIGA_SITES_DOMAIN={{ .DOMAIN_NAME }}
        TAIGA_SUBPATH=
        EMAIL_BACKEND=console
        DEFAULT_FROM_EMAIL={{ .EMAIL_DEFAULT_FROM }}
        EMAIL_USE_TLS=False
        EMAIL_USE_SSL=False
        RABBITMQ_USER={{ .RABBITMQ_USER }}
        RABBITMQ_PASS={{ .RABBITMQ_PASS }}
        ENABLE_TELEMETRY=False
        {{- end }}
        EOF
      }

      volume_mount {
        volume      = "data"
        destination = "/persistence"
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }

    task "taiga-events" {
      driver = "docker"

      config {
        image        = "docker.io/taigaio/taiga-events:${var.taiga_events_version}"
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/taiga-events.env"
        env         = true
        change_mode = "restart"

        data = <<-EOF
        {{- with nomadVar "nomad/jobs/taiga-sandbox" }}
        RABBITMQ_USER={{ .RABBITMQ_USER }}
        RABBITMQ_PASS={{ .RABBITMQ_PASS }}
        TAIGA_SECRET_KEY={{ .SECRET_KEY }}
        {{- end }}
        EOF
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }

    task "taiga-protected" {
      driver = "docker"

      config {
        image        = "docker.io/taigaio/taiga-protected:${var.taiga_protected_version}"
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/taiga-protected.env"
        env         = true
        change_mode = "restart"

        data = <<-EOF
        {{- with nomadVar "nomad/jobs/taiga-sandbox" }}
        SECRET_KEY={{ .SECRET_KEY }}
        MAX_AGE={{ .ATTACHMENTS_MAX_AGE }}
        {{- end }}
        EOF
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }

    task "taiga-front" {
      driver = "docker"

      config {
        image        = "docker.io/robrotheram/taiga-front-openid:${var.taiga_front_openid_version}"
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/taiga-front.env"
        env         = true
        change_mode = "restart"

        data = <<-EOF
        {{- with nomadVar "nomad/jobs/taiga-sandbox" }}
        TAIGA_URL=https://{{ .DOMAIN_NAME }}
        TAIGA_WEBSOCKETS_URL=wss://{{ .DOMAIN_NAME }}
        TAIGA_SUBPATH=
        # taiga-contrib-openid-auth (baked into this image). The frontend
        # only redirects to the provider's authorize endpoint; the token
        # exchange happens in taiga-back, so no client secret here.
        ENABLE_OPENID=true
        OPENID_URL={{ .OPENID_URL }}
        OPENID_CLIENT_ID={{ .OPENID_CLIENT_ID }}
        OPENID_NAME={{ .OPENID_NAME }}
        {{- end }}
        EOF
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }

    task "gateway" {
      driver = "docker"

      config {
        image        = "docker.io/library/nginx:1.19-alpine"
        entrypoint   = ["/bin/sh", "-c"]
        args = [
          "mkdir -p /taiga /persistence/static /persistence/media && ln -sfn /persistence/static /taiga/static && ln -sfn /persistence/media /taiga/media && exec nginx -g 'daemon off;'",
        ]
        volumes = [
          "local/taiga.conf:/etc/nginx/conf.d/default.conf",
        ]
      }

      # Routes to the sibling tasks over loopback, since every task in a
      # group shares one network namespace regardless of bridge vs host mode.
      template {
        destination = "local/taiga.conf"
        change_mode = "restart"

        data = <<-EOF
        server {
            listen {{ env "NOMAD_PORT_http" }} default_server;

            client_max_body_size 100M;
            charset utf-8;

            location / {
                proxy_pass http://127.0.0.1:80/;
                proxy_pass_header Server;
                proxy_set_header Host $http_host;
                proxy_redirect off;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Scheme $scheme;
            }

            location /api/ {
                proxy_pass http://127.0.0.1:8000/api/;
                proxy_pass_header Server;
                proxy_set_header Host $http_host;
                proxy_redirect off;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Scheme $scheme;
            }

            location /admin/ {
                proxy_pass http://127.0.0.1:8000/admin/;
                proxy_pass_header Server;
                proxy_set_header Host $http_host;
                proxy_redirect off;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Scheme $scheme;
            }

            location /static/ {
                alias /taiga/static/;
            }

            location /_protected/ {
                internal;
                alias /taiga/media/;
                add_header Content-disposition "attachment";
            }

            location /media/exports/ {
                alias /taiga/media/exports/;
                add_header Content-disposition "attachment";
            }

            location /media/ {
                proxy_set_header Host $http_host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Scheme $scheme;
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_pass http://127.0.0.1:8003/;
                proxy_redirect off;
            }

            location /events {
                proxy_pass http://127.0.0.1:8888/events;
                proxy_http_version 1.1;
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection "upgrade";
                proxy_connect_timeout 7d;
                proxy_send_timeout 7d;
                proxy_read_timeout 7d;
            }
        }
        EOF
      }

      volume_mount {
        volume      = "data"
        destination = "/persistence"
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }
  }
}
