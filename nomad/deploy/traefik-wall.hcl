job "traefik-wall" {
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
version = "v1.4.0"
EOF

        destination = "local/traefik.toml"
      }

      template {
        data = <<EOF
<html>
  <head>
    <title>Verifying connection</title>
    <script src="https://unpkg.com/vue@3/dist/vue.global.js"></script>
    <script src="https://unpkg.com/lux-design-system@5.6.3/dist/lux-styleguidist.iife.js"></script>
    <link rel="stylesheet" href="https://unpkg.com/lux-design-system@5.6.3/dist/style.css">
    <script src="{{ "{{" }} .FrontendJS {{ "}}" }}" async defer referrerpolicy="no-referrer"></script>
    <style>
      html,body,#app {
        margin: 0;
        display: flex;
        flex-direction: column;
        min-height: 100vh;
      }
      #content {
        flex: 1 0 0;
        width: 1440px;
        margin: auto;
        text-align: left;
        font-family: var(--font-family-heading);
        font-size: var(--font-size-base);
        line-height: var(--line-height-base);
      }
    </style>
  </head>
  <body>
    <div id="app">
      <div id="lux-header-container">
        <lux-library-header app-name="" abbr-name="" app-url="" theme="dark">
          <lux-menu-bar type="main-menu" :menu-items="[
                              {name: 'Help', component: 'Help', href: 'https://library.princeton.edu/ask-us'},
                              {name: 'Your Accounts', component: 'Account', href: 'https://library.princeton.edu/accounts'}
                              ]"
                        ></lux-menu-bar>
        </lux-library-header>
      </div>
      <div id="content">
        <h1>Traffic control and bot detection...</h1>
        <p>We've recently experienced spikes in traffic. To ensure a positive
experience for all of our patrons, please wait a moment while we verify your
connection..</p>
        <form action="{{ "{{" }} .ChallengeURL {{ "}}" }}" method="post" id="captcha-form" accept-charset="UTF-8">
          <div
              data-callback="captchaCallback"
              class="{{ "{{" }} .FrontendKey {{ "}}" }}"
              data-sitekey="{{ "{{" }} .SiteKey {{ "}}" }}"
              data-theme="auto"
              data-size="normal"
              data-language="auto"
              data-retry="auto"
              interval="8000"
              data-appearance="always">
          </div>
          <input type="hidden" name="destination" value="{{ "{{" }} .Destination {{ "}}" }}">
        </form>
        <script type="text/javascript">
          function captchaCallback(token) {
            setTimeout(function() {
              document.getElementById("captcha-form").submit();
            }, 1000);
          }
        </script>
      </div>
      <div id="lux-footer-container">
        <lux-library-footer></lux-library-footer>
      </div>
    </div>
    <script type="text/javascript">
      const { createApp } = Vue
      createApp().use(Lux.default).mount('#app')
    </script>
  </body>
</html>
EOF

        destination = "local/challenge.tmpl.html"
      }

      template {
        data = <<EOF
{{- with nomadVar "nomad/jobs/traefik-wall" -}}
[http.routers]
  [http.routers.lae-staging]
    service = "lae-staging"
    rule = "Header(`X-Forwarded-Host`, `lae-staging.princeton.edu`)"
    entrypoints = ["http"]
    middlewares = ["captcha-protect"]
  [http.routers.lae-production]
    service = "lae-production"
    rule = "Header(`X-Forwarded-Host`, `lae.princeton.edu`)"
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
[http.services]
  [http.services.lae-staging]
    [http.services.lae-staging.loadBalancer]
      [[http.services.lae-staging.loadBalancer.servers]]
        url = "http://lae-staging2.princeton.edu:80"
  [http.services.lae-production]
    [http.services.lae-production.loadBalancer]
      [[http.services.lae-production.loadBalancer.servers]]
        url = "http://lae-prod1.princeton.edu:80"
      [[http.services.lae-production.loadBalancer.servers]]
        url = "http://lae-prod2.princeton.edu:80"
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
