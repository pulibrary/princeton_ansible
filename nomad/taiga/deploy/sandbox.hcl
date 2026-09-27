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

  update {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "20s"
    healthy_deadline  = "10m"
    progress_deadline = "15m"
    auto_revert       = true
  }

  # "restart" isn't valid at the job level (only job -> group and
  # job -> group -> task), unlike update/reschedule which are -- so this
  # same block is repeated in each group below instead.

  reschedule {
    delay          = "30s"
    delay_function = "exponential"
    max_delay      = "5m"
    unlimited      = true
  }

  group "rabbitmq" {
    count = 1

    restart {
      attempts = 5
      interval = "15m"
      delay    = "15s"
      mode     = "delay"
    }

    network {
      port "amqp" {
        static = 5672
      }
    }

    service {
      name     = "taiga-rabbitmq-sandbox"
      provider = "nomad"
      port     = "amqp"

      check {
        type     = "tcp"
        port     = "amqp"
        interval = "15s"
        timeout  = "5s"
      }
    }

    task "rabbitmq" {
      driver = "docker"

      config {
        image = "docker.io/library/rabbitmq:3.13.6-management-alpine"
        ports = ["amqp"]
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
        {{- end }}
        EOF
      }

      resources {
        cpu    = 500
        memory = 768
      }
    }
  }

  group "back" {
    count = 1

    restart {
      attempts = 5
      interval = "15m"
      delay    = "15s"
      mode     = "delay"
    }

    # taiga-back, taiga-async, and the gateway all need to see the same
    # static/media files. There's only one replica of this volume, so
    # Nomad's scheduler forces all three groups onto the same node.
    volume "data" {
      type            = "host"
      source          = "taiga-sandbox"
      access_mode     = "single-node-multi-writer"
      attachment_mode = "file-system"
      sticky          = true
    }

    network {
      port "http" {
        static = 8000
      }
    }

    service {
      name     = "taiga-back-sandbox"
      provider = "nomad"
      port     = "http"

      check {
        type     = "tcp"
        port     = "http"
        interval = "15s"
        timeout  = "5s"
      }
    }

    task "taiga-back" {
      driver = "docker"

      config {
        image      = "docker.io/robrotheram/taiga-back-openid:${var.taiga_back_openid_version}"
        ports      = ["http"]
        entrypoint = ["/bin/bash", "-c"]
        args = [
          "mkdir -p /persistence/static /persistence/media && rm -rf /taiga-back/static /taiga-back/media && ln -s /persistence/static /taiga-back/static && ln -s /persistence/media /taiga-back/media && python3 -c 'p = \"/taiga-back/taiga/projects/migrations/0046_triggers_to_update_tags_colors.py\"; s = open(p).read(); s = s.replace(\"array_agg_mult (anyarray)\", \"array_agg_mult (anycompatiblearray)\"); s = s.replace(\"= anyarray\", \"= anycompatiblearray\"); open(p, \"w\").write(s)' && python3 -c 'p = \"/taiga-back/settings/config.py\"; s = open(p).read(); s = s.replace(\"DEBUG = False\", \"DEBUG = True\"); open(p, \"w\").write(s)' && exec /taiga-back/docker/entrypoint.sh --timeout 120",
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
        {{- $rmq := "" }}
        {{- range nomadService "taiga-rabbitmq-sandbox" }}{{ $rmq = (printf "%s:%d" .Address .Port) }}{{ end }}
        CELERY_BROKER_URL=amqp://{{ .RABBITMQ_USER }}:{{ .RABBITMQ_PASS }}@{{ $rmq }}/{{ .RABBITMQ_VHOST }}
        EVENTS_PUSH_BACKEND=taiga.events.backends.rabbitmq.EventsPushBackend
        EVENTS_PUSH_BACKEND_URL=amqp://{{ .RABBITMQ_USER }}:{{ .RABBITMQ_PASS }}@{{ $rmq }}/{{ .RABBITMQ_VHOST }}
        ENABLE_TELEMETRY=False
        # taiga-contrib-openid-auth (baked into this image). taiga-back
        # only needs the token-exchange settings; OPENID_URL and
        # OPENID_NAME are consumed by taiga-front below instead.
        ENABLE_OPENID=True
        # Without this, taiga_contrib_openid_auth.services.openid_register
        # rejects any OpenID login for a user with no existing Taiga
        # account ("registrations have been disabled by the
        # Administrator") -- there's no other way in, since this image's
        # entrypoint never seeds the taigaio/taiga-back
        # users/fixtures/initial_user.json admin/123123 account.
        PUBLIC_REGISTER_ENABLED=True
        OPENID_USER_URL={{ .OPENID_USER_URL }}
        OPENID_TOKEN_URL={{ .OPENID_TOKEN_URL }}
        OPENID_CLIENT_ID={{ .OPENID_CLIENT_ID }}
        OPENID_CLIENT_SECRET={{ .OPENID_CLIENT_SECRET }}
        # Must match the frontend plugin's actual authorize-request scope,
        # or Microsoft's token endpoint rejects the exchange with
        # invalid_grant (confirmed against a real login attempt's network
        # trace). The plugin's front/coffee/openid-auth.coffee source on
        # GitHub defaults this to "User.Read" with no env override, but
        # the deployed robrotheram/taiga-front-openid:latest image is
        # evidently built from a different version that defaults to
        # "openid email" instead -- same kind of version drift as the
        # stale migration patched in taiga-back's args above. "openid
        # email" is also the more correct pairing for
        # graph.microsoft.com/oidc/userinfo anyway (that's the actual
        # OIDC userinfo endpoint, not a general Graph API call).
        OPENID_SCOPE=openid email
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
  }

  group "async" {
    count = 1

    restart {
      attempts = 5
      interval = "15m"
      delay    = "15s"
      mode     = "delay"
    }

    volume "data" {
      type            = "host"
      source          = "taiga-sandbox"
      access_mode     = "single-node-multi-writer"
      attachment_mode = "file-system"
      sticky          = true
    }

    task "taiga-async" {
      driver = "docker"

      config {
        image      = "docker.io/taigaio/taiga-back:${var.taiga_back_version}"
        entrypoint = ["/bin/bash", "-c"]
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
        {{- $rmq := "" }}
        {{- range nomadService "taiga-rabbitmq-sandbox" }}{{ $rmq = (printf "%s:%d" .Address .Port) }}{{ end }}
        CELERY_BROKER_URL=amqp://{{ .RABBITMQ_USER }}:{{ .RABBITMQ_PASS }}@{{ $rmq }}/{{ .RABBITMQ_VHOST }}
        EVENTS_PUSH_BACKEND=taiga.events.backends.rabbitmq.EventsPushBackend
        EVENTS_PUSH_BACKEND_URL=amqp://{{ .RABBITMQ_USER }}:{{ .RABBITMQ_PASS }}@{{ $rmq }}/{{ .RABBITMQ_VHOST }}
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
  }

  group "events" {
    count = 1

    restart {
      attempts = 5
      interval = "15m"
      delay    = "15s"
      mode     = "delay"
    }

    network {
      port "http" {
        static = 8888
      }
    }

    service {
      name     = "taiga-events-sandbox"
      provider = "nomad"
      port     = "http"

      check {
        type     = "tcp"
        port     = "http"
        interval = "15s"
        timeout  = "5s"
      }
    }

    task "taiga-events" {
      driver = "docker"

      config {
        image = "docker.io/taigaio/taiga-events:${var.taiga_events_version}"
        ports = ["http"]
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/taiga-events.env"
        env         = true
        change_mode = "restart"

        data = <<-EOF
        {{- with nomadVar "nomad/jobs/taiga-sandbox" }}
        {{- $rmq := "" }}
        {{- range nomadService "taiga-rabbitmq-sandbox" }}{{ $rmq = (printf "%s:%d" .Address .Port) }}{{ end }}
        RABBITMQ_USER={{ .RABBITMQ_USER }}
        RABBITMQ_PASS={{ .RABBITMQ_PASS }}
        RABBITMQ_URL=amqp://{{ .RABBITMQ_USER }}:{{ .RABBITMQ_PASS }}@{{ $rmq }}/{{ .RABBITMQ_VHOST }}
        TAIGA_SECRET_KEY={{ .SECRET_KEY }}
        {{- end }}
        EOF
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }

  group "protected" {
    count = 1

    restart {
      attempts = 5
      interval = "15m"
      delay    = "15s"
      mode     = "delay"
    }

    network {
      port "http" {
        static = 8003
      }
    }

    service {
      name     = "taiga-protected-sandbox"
      provider = "nomad"
      port     = "http"

      check {
        type     = "tcp"
        port     = "http"
        interval = "15s"
        timeout  = "5s"
      }
    }

    task "taiga-protected" {
      driver = "docker"

      config {
        image = "docker.io/taigaio/taiga-protected:${var.taiga_protected_version}"
        ports = ["http"]
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
  }

  group "front" {
    count = 1

    restart {
      attempts = 5
      interval = "15m"
      delay    = "15s"
      mode     = "delay"
    }

    network {
      port "http" {
        static = 80
      }
    }

    service {
      name     = "taiga-front-sandbox"
      provider = "nomad"
      port     = "http"

      check {
        type     = "tcp"
        port     = "http"
        interval = "15s"
        timeout  = "5s"
      }
    }

    task "taiga-front" {
      driver = "docker"

      config {
        image = "docker.io/robrotheram/taiga-front-openid:${var.taiga_front_openid_version}"
        ports = ["http"]
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
  }

  group "gateway" {
    count = 1

    restart {
      attempts = 5
      interval = "15m"
      delay    = "15s"
      mode     = "delay"
    }

    consul {}

    volume "data" {
      type            = "host"
      source          = "taiga-sandbox"
      access_mode     = "single-node-multi-writer"
      attachment_mode = "file-system"
      sticky          = true
    }

    network {
      port "http" {}
    }

    service {
      name = "taiga-sandbox"
      port = "http"
      tags = ["logging"]

      # No check_restart here on purpose: it deadlocked this exact job
      # once already. See nomad/taiga/README.md.
      check {
        type     = "http"
        port     = "http"
        path     = "/"
        interval = "15s"
        timeout  = "5s"
      }
    }

    task "gateway" {
      driver = "docker"

      config {
        image      = "docker.io/library/nginx:1.19-alpine"
        ports      = ["http"]
        entrypoint = ["/bin/sh", "-c"]
        args = [
          "mkdir -p /taiga /persistence/static /persistence/media && ln -sfn /persistence/static /taiga/static && ln -sfn /persistence/media /taiga/media && exec nginx -g 'daemon off;'",
        ]
        volumes = [
          "local/taiga.conf:/etc/nginx/conf.d/default.conf",
        ]
      }

      template {
        destination = "local/taiga.conf"
        change_mode = "restart"

        data = <<-EOF
        {{- $front := "127.0.0.1:1" }}
        {{- range nomadService "taiga-front-sandbox" }}{{ $front = (printf "%s:%d" .Address .Port) }}{{ end }}
        {{- $back := "127.0.0.1:1" }}
        {{- range nomadService "taiga-back-sandbox" }}{{ $back = (printf "%s:%d" .Address .Port) }}{{ end }}
        {{- $events := "127.0.0.1:1" }}
        {{- range nomadService "taiga-events-sandbox" }}{{ $events = (printf "%s:%d" .Address .Port) }}{{ end }}
        {{- $protected := "127.0.0.1:1" }}
        {{- range nomadService "taiga-protected-sandbox" }}{{ $protected = (printf "%s:%d" .Address .Port) }}{{ end }}
        server {
            listen {{ env "NOMAD_PORT_http" }} default_server;

            # Temporary: the default "error" level isn't showing anything
            # for a 500 that returns nginx's own default error page (no
            # CORS headers, Content-Type: text/html) for POST /api/v1/auth
            # -- neither this gateway's error log nor taiga-back's own
            # logs show any trace of it. "info" (not "debug" -- the stock
            # nginx:1.19-alpine build isn't a --with-debug build, so a
            # "debug" level silently produces nothing) should at least
            # show the upstream connection attempt and what came back.
            # Remove once this is root-caused.
            error_log /dev/stderr info;

            # The failing requests never show a proxy attempt in the log
            # above at all (no upstream connect, successful or failed) --
            # meaning nginx is rejecting them before location routing even
            # happens, which is consistent with its own default error
            # page (no CORS headers, text/html) rather than anything from
            # taiga-back. The one thing distinctive about these requests:
            # the Referer header is the full /login?code=...&session_
            # state=... URL, and Entra ID (with Continuous Access
            # Evaluation) issues authorization codes long enough to push
            # that single header past nginx's small stock defaults.
            # Bumped generously; safe to leave in place either way.
            client_header_buffer_size 32k;
            large_client_header_buffer_size 4 32k;

            client_max_body_size 100M;
            charset utf-8;

            location / {
                proxy_pass http://{{ $front }}/;
                proxy_pass_header Server;
                proxy_set_header Host $http_host;
                proxy_redirect off;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Scheme $scheme;
            }

            location /api/ {
                proxy_pass http://{{ $back }}/api/;
                proxy_pass_header Server;
                proxy_set_header Host $http_host;
                proxy_redirect off;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Scheme $scheme;
            }

            location /admin/ {
                proxy_pass http://{{ $back }}/admin/;
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
                proxy_pass http://{{ $protected }}/;
                proxy_redirect off;
            }

            location /events {
                proxy_pass http://{{ $events }}/events;
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
