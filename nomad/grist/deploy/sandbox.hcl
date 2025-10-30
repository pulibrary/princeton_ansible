variable "branch_or_sha" {
  type    = string
  default = "main"
}

variable "grist_image" {
  type    = string
  default = "docker.io/gristlabs/grist:1.7.4"
}

variable "grist_data_root" {
  type    = string
  default = "/data/grist"
}

job "grist" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "all"

  group "grist-all" {
    count = 1

    network {
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
  env {
    PORT = "8484"
    GRIST_HOST = "0.0.0.0"
    GRIST_SINGLE_PORT = "true"
    GRIST_ORG_IN_PATH = "true"
    GRIST_SERVE_SAME_ORIGIN = "true"
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

    GRIST_SAML_IDP_UNENCRYPTED = "1"

    # GRIST_SAML_IDP_SKIP_SLO = "1"

    # Proxies we trust (so Host/XFF are honored)
    GRIST_TRUSTED_PROXY = "10.0.0.0/8,127.0.0.1/32"
  }

  resources {
    cpu    = 2000
    memory = 2048
  }

  service {
    name         = "grist-sandbox"
    port         = "http"
    #    address_mode = "driver"
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
        attempts = 5
        delay    = "20s"
        mode     = "delay"
      }

    }
  }
}

