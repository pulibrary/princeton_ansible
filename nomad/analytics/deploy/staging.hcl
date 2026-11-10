variable "branch_or_sha" {
  type = string
  default = "main"
}

job "analytics-staging" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  node_pool = "staging"

  # Need a tiny redis store to keep the Entra Oauth cookies in.
  # Don't gotta persist it - when we redeploy, folks will just have to log in again.
  group "sessions" {
    count = 1

    network {
      port "redis" {
        # Static port so we can reference it in the oauth env config.
        static = 6380
        to     = 6379
      }
    }

    service {
      name = "analytics-staging-sessions"
      port = "redis"

      check {
        type     = "tcp"
        port     = "redis"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "redis" {
      driver = "docker"

      config {
        image = "redis:8.10-alpine"
        ports = ["redis"]
        args  = ["/secrets/redis.conf"]
        readonly_rootfs = true
        cap_drop = ["ALL"]
        security_opt = [
          "no-new-privileges"
        ]
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/redis.conf"
        change_mode = "restart"
        data = <<EOF
save ""
appendonly no
maxmemory 64mb
maxmemory-policy volatile-lru
{{- with nomadVar "nomad/jobs/analytics-staging" }}
requirepass {{ .OAUTH2_REDIS_PASSWORD }}
{{- end }}
EOF
      }

      resources {
        cpu    = 100
        memory = 96
      }
    }
  }

  group "web" {
    count = 2

    update {
      canary = 1
      auto_promote = true
      auto_revert = true
    }

    network {
      port "http" { to = 3000 }
      port "auth" { to = 4180 }
      port "web" { to = 8080 }

      dns {
        servers = ["172.17.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    service {
      tags = ["live"]
      canary_tags = ["canary"]
      port = "web"

      check {
        type = "http"
        port = "web"
        path = "/api/heartbeat"
        interval = "10s"
        timeout  = "2s"
      }

      check {
        type = "http"
        port = "auth"
        path = "/ping"
        interval = "10s"
        timeout  = "2s"
      }
    }

    # oauth2-proxy handles Entra auth and passes it to nginx to decide which Umami token to log in with.
    task "oauth2-proxy" {
      driver = "docker"

      identity {
        name = "entra"
        aud  = ["api://AzureADTokenExchange"]
        file = true
        ttl  = "15m"
      }

      config {
        image = "quay.io/oauth2-proxy/oauth2-proxy:v7.15.6"
        ports = ["auth"]
        readonly_rootfs = true
        cap_drop = ["ALL"]
        security_opt = [
          "no-new-privileges"
        ]
      }

      env {
        OAUTH2_PROXY_HTTP_ADDRESS = "0.0.0.0:4180"
        # Forward Entra properties to nginx, so it can set the right token.
        OAUTH2_PROXY_SET_XAUTHREQUEST = "true"
        OAUTH2_PROXY_PROVIDER = "entra-id"
        OAUTH2_PROXY_CLIENT_ID = "8a100d7f-f364-4790-ba41-1a01afaa42f7"
        OAUTH2_PROXY_OIDC_ISSUER_URL = "https://login.microsoftonline.com/2ff60116-7431-425d-b5af-077d7791bda4/v2.0"
        # Get offline_access so it refreshes the token every hour, so if we remove someone from a group it propagates in an hour.
        OAUTH2_PROXY_SCOPE = "openid email profile offline_access"
        OAUTH2_PROXY_COOKIE_REFRESH = "1h"
        OAUTH2_PROXY_CODE_CHALLENGE_METHOD = "S256"
        OAUTH2_PROXY_ENTRA_ID_FEDERATED_TOKEN_AUTH = "true"
        # Use nomad workload identities to auth to Entra.
        AZURE_FEDERATED_TOKEN_FILE = "/secrets/nomad_entra.jwt"
        OAUTH2_PROXY_REDIRECT_URL = "https://analytics-staging.lib.princeton.edu/oauth2/callback"
        OAUTH2_PROXY_EMAIL_DOMAINS = "*"
        OAUTH2_PROXY_OIDC_GROUPS_CLAIM = "roles"
        # Gotta be in a group or you can't get in. These are managed in Entra.
        OAUTH2_PROXY_ALLOWED_GROUPS = "AnalyticsAdmin,AnalyticsViewer"
        OAUTH2_PROXY_REVERSE_PROXY = "true"
        OAUTH2_PROXY_TRUSTED_PROXY_IPS = "172.16.0.0/12"
        OAUTH2_PROXY_SKIP_PROVIDER_BUTTON = "true"
        # Store sessions in redis, otherwise the cookie gets too big and nginx errors.
        # Docs: https://oauth2-proxy.github.io/oauth2-proxy/configuration/integrations/nginx#configuring-for-use-with-the-nginx-auth_request-directive
        OAUTH2_PROXY_COOKIE_SECURE = "true"
        OAUTH2_PROXY_SESSION_STORE_TYPE = "redis"
        OAUTH2_PROXY_REDIS_CONNECTION_URL = "redis://analytics-staging-sessions.service.consul:6380"
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/analytics-staging" -}}
        OAUTH2_PROXY_COOKIE_SECRET = '{{ .OAUTH2_COOKIE_SECRET }}'
        OAUTH2_PROXY_REDIS_PASSWORD = '{{ .OAUTH2_REDIS_PASSWORD }}'
        {{- end -}}
        EOF
      }

      resources {
        cpu    = 200
        memory = 128
      }
    }

    # Nginx proxy to handle auth flow.
    # If not logged in, forward to oauth2-proxy
    # If logged in by oauth2-proxy (headers set), check groups, if group is correct then set the Bearer token to the admin or viewer Umami user appropriately.
    # NOTE: This only works because Umami's bearer tokens for accounts never expire.
    task "nginx" {
      driver = "docker"

      config {
        image = "docker.io/nginxinc/nginx-unprivileged:stable"
        ports = ["web"]
        readonly_rootfs = true
        cap_drop = ["ALL"]
        security_opt = [
          "no-new-privileges"
        ]
        volumes = [
          "secrets/nginx.conf:/etc/nginx/nginx.conf",
          "local/proxy_headers.conf:/etc/nginx/proxy_headers.conf",
        ]
        mount {
          type   = "tmpfs"
          target = "/tmp"
        }
        mount {
          type   = "tmpfs"
          target = "/var/cache/nginx"
          tmpfs_options {
            mode = 1023
          }
        }
      }

      template {
        destination = "local/proxy_headers.conf"
        change_mode = "restart"
        data = <<EOF
proxy_http_version 1.1;
proxy_set_header Host $http_host;
proxy_set_header X-Real-IP $http_x_real_ip;
proxy_set_header X-Forwarded-For $http_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
proxy_set_header X-Forwarded-Host $http_x_forwarded_host;
EOF
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/nginx.conf"
        change_mode = "restart"
        data = <<EOF
pid /tmp/nginx.pid;
worker_processes 1;
events {
  worker_connections 1024;
}
http {
  access_log off;
  error_log /dev/stderr warn;
  server_tokens off;
  absolute_redirect off;

  upstream umami {
    server {{ env "NOMAD_ADDR_http" }};
  }
  upstream oauth2 {
    server {{ env "NOMAD_ADDR_auth" }};
  }
  upstream denied {
    server 127.0.0.1:8081;
  }

  {{- if nomadVarExists "nomad/jobs/analytics-staging/web/nginx" }}
  {{- with nomadVar "nomad/jobs/analytics-staging/web/nginx" }}
  map $auth_groups $umami_token {
    default "";
    "~(^|,)AnalyticsAdmin(,|$)" "{{ .UMAMI_ADMIN_TOKEN }}";
    "~(^|,)AnalyticsViewer(,|$)" "{{ .UMAMI_VIEWER_TOKEN }}";
  }
  {{- end }}
  {{- else }}
  map $auth_groups $umami_token {
    default "";
  }
  {{- end }}

  map $umami_token $umami_backend {
    "" http://denied;
    default http://umami;
  }

  server {
    listen 127.0.0.1:8081;
    return 403;
  }

  server {
    listen 8080;

    location ~ ^/(script\.js|recorder\.js|api/(send|batch|record|heartbeat))$ {
      proxy_pass http://umami;
      include proxy_headers.conf;
      proxy_set_header Authorization "";
    }

    location = /oauth2/auth {
      internal;
      proxy_pass http://oauth2;
      include proxy_headers.conf;
      proxy_set_header X-Forwarded-Uri $request_uri;
      proxy_set_header Content-Length "";
      proxy_pass_request_body off;
    }

    location /oauth2/ {
      proxy_pass http://oauth2;
      include proxy_headers.conf;
    }

    location @oauth2_signin {
      rewrite ^ /oauth2/start? break;
      proxy_pass http://oauth2;
      include proxy_headers.conf;
      proxy_set_header X-Auth-Request-Redirect $request_uri;
    }

    location = /login {
      return 302 /;
    }

    location = /logout {
      return 302 /oauth2/sign_out;
    }

    location / {
      auth_request /oauth2/auth;
      auth_request_set $auth_groups $upstream_http_x_auth_request_groups;
      error_page 401 = @oauth2_signin;

      auth_request_set $auth_cookie $upstream_http_set_cookie;
      add_header Set-Cookie $auth_cookie;

      proxy_pass $umami_backend;
      include proxy_headers.conf;
      proxy_set_header Authorization "Bearer $umami_token";
    }
  }
}
EOF
      }

      resources {
        cpu    = 200
        memory = 64
      }
    }

    task "app" {
      driver = "docker"

      # This is set in the Dockerfile, but set it explicitly in case they change that.
      user = "1001:1001"

      config {
        image        = "ghcr.io/umami-software/umami:3.4.1"
        ports = ["http"]
        # Don't allow writing anything to the file system.
        readonly_rootfs = true
        # We don't need any CAP privileges - don't allow any privilege escalation.
        cap_drop = ["ALL"]
        security_opt = [
          "no-new-privileges"
        ]
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/analytics-staging" -}}
        DATABASE_TYPE = 'postgresql'
        APP_SECRET = '{{ .SECRET_KEY_BASE }}'
        DATABASE_URL = 'postgresql://{{ .DB_USER }}:{{ .DB_PASSWORD }}@{{ .POSTGRES_HOST }}:5432/{{ .DB_NAME }}'
        {{- end -}}
        EOF
      }

      resources {
        cpu    = 1000
        memory = 2048
      }
    }
  }
}
