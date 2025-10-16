variable "branch_or_sha" {
  type    = string
  default = "main"
}

variable "grist_image" {
  type    = string
  default = "docker.io/gristlabs/grist:latest"
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

    # Grist app
    task "grist" {
      driver = "podman"

      config {
        image        = var.grist_image
        network_mode = "host"

        # persistent state
        # selinux (Rocky/RHEL) may need:
        #   sudo chcon -Rt container_file_t /data/grist
        volumes = [
          "/data/grist:/persist",
          "/data/grist/docs:/persist/docs"
        ]
      }

      # Defaults mirror the Dockerfile ENV so it "just works" on first run.
      env {
        GRIST_ORG_IN_PATH                         = "true"
        GRIST_HOST                                = "0.0.0.0"
        GRIST_SINGLE_PORT                         = "true"
        GRIST_SERVE_SAME_ORIGIN                   = "true"
        GRIST_DATA_DIR                            = "/persist/docs"
        GRIST_INST_DIR                            = "/persist"
        GRIST_SESSION_COOKIE                      = "grist_core"
        GRIST_ALLOW_AUTOMATIC_VERSION_CHECKING    = "false"
        GVISOR_FLAGS                              = "-unprivileged -ignore-cgroups"
        GRIST_SANDBOX_FLAVOR                      = "unsandboxed"
        NODE_OPTIONS                              = "--no-deprecation"
        NODE_ENV                                  = "production"
        TYPEORM_DATABASE                          = "/persist/home.sqlite3"

        DEPLOY_BRANCH_OR_SHA                      = var.branch_or_sha
      }

      service {
        name         = "grist-ui-sandbox"
        address_mode = "driver"
        port         = 8484

        check {
          type         = "tcp"
          interval     = "10s"
          timeout      = "2s"
          address_mode = "driver"
          port         = 8484
        }
      }

      resources {
        cpu    = 2000
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

