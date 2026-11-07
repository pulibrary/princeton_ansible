variable "branch_or_sha" {
  type = string
  default = "main"
}

job "analytics-staging" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  node_pool = "staging"

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
        servers = ["10.88.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
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
        OAUTH2_PROXY_UPSTREAMS = "static://202"
        OAUTH2_PROXY_SET_XAUTHREQUEST = "true"
        OAUTH2_PROXY_PROVIDER = "entra-id"
        OAUTH2_PROXY_CLIENT_ID = "REPLACE-WITH-ENTRA-APP-CLIENT-ID"
        OAUTH2_PROXY_OIDC_ISSUER_URL = "https://login.microsoftonline.com/2ff60116-7431-425d-b5af-077d7791bda4/v2.0"
        OAUTH2_PROXY_SCOPE = "openid email profile offline_access"
        OAUTH2_PROXY_COOKIE_REFRESH = "1h"
        OAUTH2_PROXY_CODE_CHALLENGE_METHOD = "S256"
        OAUTH2_PROXY_ENTRA_ID_FEDERATED_TOKEN_AUTH = "true"
        AZURE_FEDERATED_TOKEN_FILE = "/secrets/nomad_entra.jwt"
        OAUTH2_PROXY_REDIRECT_URL = "https://analytics-staging.lib.princeton.edu/oauth2/callback"
        OAUTH2_PROXY_EMAIL_DOMAINS = "*"
        OAUTH2_PROXY_OIDC_GROUPS_CLAIM = "roles"
        OAUTH2_PROXY_ALLOWED_GROUPS = "AnalyticsAdmin,AnalyticsViewer"
        OAUTH2_PROXY_REVERSE_PROXY = "true"
        OAUTH2_PROXY_SKIP_PROVIDER_BUTTON = "true"
        OAUTH2_PROXY_COOKIE_SECURE = "true"
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/analytics-staging" -}}
        OAUTH2_PROXY_COOKIE_SECRET = '{{ .OAUTH2_COOKIE_SECRET }}'
        {{- end -}}
        EOF
      }

      resources {
        cpu    = 200
        memory = 128
      }
    }

    task "nginx" {
      driver = "docker"

      config {
        image = "docker.io/nginxinc/nginx-unprivileged:1.30.6-alpine"
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
  client_body_temp_path /tmp/client_temp;
  proxy_temp_path /tmp/proxy_temp;
  fastcgi_temp_path /tmp/fastcgi_temp;
  uwsgi_temp_path /tmp/uwsgi_temp;
  scgi_temp_path /tmp/scgi_temp;
  access_log off;
  error_log /dev/stderr warn;
  server_tokens off;
  absolute_redirect off;
  large_client_header_buffers 4 32k;

  upstream umami {
    server {{ env "NOMAD_ADDR_http" }};
  }
  upstream oauth2 {
    server {{ env "NOMAD_ADDR_auth" }};
  }
  upstream denied {
    server 127.0.0.1:8081;
  }

  {{- with nomadVar "nomad/jobs/analytics-staging" }}
  map $auth_groups $umami_token {
    default "";
    "~(^|,)AnalyticsAdmin(,|$)" "{{ .UMAMI_ADMIN_TOKEN }}";
    "~(^|,)AnalyticsViewer(,|$)" "{{ .UMAMI_VIEWER_TOKEN }}";
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

    location @signin {
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
      error_page 401 = @signin;
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
