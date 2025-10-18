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

    task "init-storage" {
      driver = "raw_exec"
      lifecycle {
        hook = "prestart"
      }

      config {
        command = "/bin/sh"
        args = ["-lc", <<EOT
set -euo pipefail
mkdir -p ${var.grist_data_root}/docs ${var.grist_data_root}/saml
chown -R 1000:1000 ${var.grist_data_root}
chmod -R 750 ${var.grist_data_root}
# If SELinux:
command -v chcon >/dev/null 2>&1 && chcon -Rt container_file_t ${var.grist_data_root} || true
EOT
        ]
      }

      resources {
        cpu = 50
        memory = 32
      }
    }

    # Main app
    task "grist" {
      driver = "podman"

      config {
        image        = var.grist_image
        network_mode = "host"
        volumes = [
          "${var.grist_data_root}:/persist",
          "${var.grist_data_root}/docs:/persist/docs",
          "${var.grist_data_root}/saml:/persist/saml",
        ]
      }

      env {
        # Base Grist config
        GRIST_HOST              = "0.0.0.0"
        GRIST_SINGLE_PORT       = "true"
        GRIST_SERVE_SAME_ORIGIN = "true"
        GRIST_DATA_DIR          = "/persist/docs"
        GRIST_INST_DIR          = "/persist"
        NODE_OPTIONS            = "--no-deprecation"
        NODE_ENV                = "production"
        TYPEORM_DATABASE        = "/persist/home.sqlite3"

        # ====== SAML (Microsoft Entra ID) ======
        # External URL of Grist (public)
        GRIST_SAML_SP_HOST    = "https://sandbox-cdh-sheets.lib.princeton.edu"

        # Paths INSIDE container to SP key/cert (we’ll render them via Ansible Vault)
        GRIST_SAML_SP_KEY     = "/persist/saml/sp.key"
        GRIST_SAML_SP_CERT    = "/persist/saml/sp.crt"

        # Entra (Azure AD) endpoints — use your tenant ID-specific SAML endpoints
        GRIST_SAML_IDP_LOGIN  = "https://login.microsoftonline.com/<TENANT_ID>/saml2"
        GRIST_SAML_IDP_LOGOUT = "https://login.microsoftonline.com/<TENANT_ID>/saml2"

        # IdP signing cert(s) rendered by Ansible to this path (PEM)
        GRIST_SAML_IDP_CERTS  = "/persist/saml/entra-idp.crt"

        # Uncomment if you AREN'T encrypting assertions in Entra and want to accept signed + HTTPS:
        # GRIST_SAML_IDP_UNENCRYPTED = "1"

        # SLO start simple
        GRIST_SAML_IDP_SKIP_SLO = "1"

        # Traceability
        DEPLOY_BRANCH_OR_SHA  = var.branch_or_sha
      }

      service {
        name         = "grist-ui-sandbox"
        address_mode = "driver"
        port         = 8484

        # TCP because of odd Host header issues
        check {
          type         = "tcp"
          interval     = "10s"
          timeout      = "2s"
          address_mode = "driver"
          port         = 8484
        }
      }

      resources {
        cpu = 2000
        memory = 2048
      }

      restart {
        attempts = 5
        delay    = "20s"
        mode     = "delay"
      }
    }
  }
}

