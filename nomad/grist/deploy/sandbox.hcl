variable "branch_or_sha" {
  type    = string
  default = "main"
}

job "grist" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "all"

  group "grist-all" {
    count = 1

    network {
      dns {
        servers = ["10.88.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
      mode = "host"
      port "http" {
        static = 8484
      }
    }

    # Main app
task "grist" {
  driver = "podman"

  config {
    image        = "docker.io/gristlabs/grist:1.7.4"
    network_mode = "host"
    volumes = [
      "/data/grist:/persist",
      "/etc/grist-saml:/idp:ro:Z"
    ]
  }

  # minimal env file, no nomadVar usage
  template {
    destination = "${NOMAD_SECRETS_DIR}/env.vars"
    env         = true
    change_mode = "restart"
    data = <<EOF
GRIST_ORG_IN_PATH = true
GRIST_HOST = "0.0.0.0"
GRIST_SINGLE_PORT = true
GRIST_SERVE_SAME_ORIGIN = true
GRIST_DATA_DIR = "/persist/docs"
GRIST_INST_DIR = "/persist"
GRIST_SESSION_COOKIE = "grist_core"
GRIST_SANDBOX_FLAVOR = "unsandboxed"
NODE_OPTIONS = "--no-deprecation"
NODE_ENV = "production"
TYPEORM_DATABASE = "/persist/home.sqlite3"

# SAML base URL for staging
GRIST_SAML_SP_HOST = "https://pul-sheets-staging.lib.princeton.edu"

# SAML file paths (mounted from host)
GRIST_SAML_SP_KEY  = "/idp/sp.key"
GRIST_SAML_SP_CERT = "/idp/sp.crt"
GRIST_SAML_IDP_CERTS = "/idp/idp_1.cer"

# Entra endpoints (from your tenant)
GRIST_SAML_IDP_LOGIN  = "https://login.microsoftonline.com/2ff60116-7431-425d-b5af-077d7791bda4/saml2"
GRIST_SAML_IDP_LOGOUT = "https://login.microsoftonline.com/2ff60116-7431-425d-b5af-077d7791bda4/logout.saml"

# If your IdP is sending unencrypted assertions (optional):
# GRIST_SAML_IDP_UNENCRYPTED = "1"

# If you don’t have SingleLogout configured (optional):
# GRIST_SAML_IDP_SKIP_SLO = "1"

# Proxies you trust (so Host/XFF are honored)
GRIST_TRUSTED_PROXY = "10.0.0.0/8,127.0.0.1/32"
EOF
  }

  resources {
    cpu    = 2000
    memory = 2048
  }

  service {
    name         = "grist-sandbox"
    port         = "http"
    address_mode = "host"
    check {
      type         = "http"
      path         = "/"
      interval     = "10s"
      timeout      = "2s"
      port         = "http"
      address_mode = "host"
    }
  }
      restart {
        attempts = 6
        delay    = "20s"
        mode     = "delay"
      }

    }
  }
}

