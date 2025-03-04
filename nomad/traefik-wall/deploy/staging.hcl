variable "branch_or_sha" {
  type = string
  default = "main"
}

job "traefik-wall-staging" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  node_pool = "staging"

  group "traefik" {
    count = 2

    network {
      port "http" { }

      dns {
        servers = ["10.88.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    service {
      name = "traefik-wall-staging"
      tags = ["node-${NOMAD_ALLOC_INDEX}"]
      port = "http"

      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "traefik" {
      driver = "podman"

      config {
        image        = "docker.io/library/traefik:v3.3"
        network_mode = "host"

        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
          "local/dynamic.toml:/etc/traefik/dynamic.toml",
          "local/challenge.tmpl.html:/challenge.tmpl.html"
        ]
      }

      template {
        data = <<EOF
defaultEntryPoints = ["http"]

[log]
  level = "DEBUG"

[entryPoints]
   [entryPoints.http]
     address = ":{{ env "NOMAD_PORT_http" }}"
   [entryPoints.http.forwardedHeaders]
     trustedIPs = ["128.112.200.245/32", "128.112.201.34/32"]
   [entryPoints.traefik]
     address = ":9091"

[api]
  dashboard = false
  insecure  = false

[providers]
  [providers.file]
    filename = "/etc/traefik/dynamic.toml"
[experimental.plugins.captcha-protect]
modulename = "github.com/libops/captcha-protect"
version = "v1.5.0"
EOF

        destination = "local/traefik.toml"
      }

      artifact {
        source = "https://raw.githubusercontent.com/pulibrary/princeton_ansible/${ var.branch_or_sha }}/nomad/traefik-wall/deploy/challenge.tmpl.html"
        destination = "local/challenge.tmpl.html"
        mode = "file"
      }

      template {
        data = <<EOF
{{- with nomadVar "nomad/jobs/traefik-wall-staging" -}}
[http.routers]
  [http.routers.lae-staging]
    service = "lae-staging"
    rule = "Header(`X-Forwarded-Host`, `lae-staging.princeton.edu`)"
    entrypoints = ["http"]
    middlewares = ["captcha-protect"]
[http.middlewares.captcha-protect.plugin.captcha-protect]
  protectRoutes =  "/catalog"
  captchaProvider =  "turnstile"
  siteKey =  "{{ .TURNSTILE_SITE_KEY }}"
  secretKey =  "{{ .TURNSTILE_SECRET_KEY }}"
  goodBots = "apple.com,archive.org,duckduckgo.com,facebook.com,google.com,googlebot.com,googleusercontent.com,instagram.com,kagibot.org,linkedin.com,msn.com,openalex.org,twitter.com,x.com"
  persistentStateFile = "/tmp/state.json"
  ipForwardedHeader = "X-Forwarded-For"
  rateLimit = 20
  protectParameters = "true"
  exemptIps = ["128.112.200.245/32", "128.112.201.34/32"]
  challengeTmpl = "/challenge.tmpl.html"
  excludeRoutes = "/catalog/facet"
[http.services]
  [http.services.lae-staging]
    [http.services.lae-staging.loadBalancer]
      [[http.services.lae-staging.loadBalancer.servers]]
        url = "http://lae-staging2.princeton.edu:80"
{{- end -}}
EOF

        destination = "local/dynamic.toml"
      }

      resources {
        cpu    = 1000
        memory = 512
      }
    }
  }
}
