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
