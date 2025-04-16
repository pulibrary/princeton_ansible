variable "branch_or_sha" {
  type = string
  default = "main"
}

job "traefik-wall-testing" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  node_pool = "production"

  # Configure a Traefik node which will challenge everyone - we only expect this to turn on when under attack.
  group "traefik-test-challenge" {
    # Only one high challenge node, otherwise everyone gets captcha'd twice.
    count = 1

    network {
      port "http" { }
      port "traefik" { }
      port "metrics" { }

      dns {
        servers = ["10.88.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    service {
      name = "traefik-wall-testing"
      tags = ["testchallenge", "node-${NOMAD_ALLOC_INDEX}"]
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

      env {
        ## These are higher challenge ones, uncomment these for the test:
        # Challenge after only 4 request.
        # rate_limit = 4
        ## This is the current low challenge ones, comment these out for test:
        rate_limit = 20
        subnet_mask = 16
      }

      config {
        image        = "docker.io/library/traefik:v3.3"
        ports = ["http", "traefik", "metrics"]

        volumes = [
          "local/traefik.yml:/etc/traefik/traefik.yml",
          "local/traefik-config:/etc/traefik/config.d",
          "local/challenge.tmpl.html:/challenge.tmpl.html"
        ]
      }

      # Static Configuration
      artifact {
        source = "https://raw.githubusercontent.com/pulibrary/princeton_ansible/${ var.branch_or_sha }/nomad/traefik-wall/deploy/traefik.tpl.yml"
      }

      template {
        source = "local/traefik.tpl.yml"
        destination = "local/traefik.yml"
      }

      # Plugin Configuration
      artifact {
        source = "https://raw.githubusercontent.com/pulibrary/princeton_ansible/${ var.branch_or_sha }/nomad/traefik-wall/deploy/bot-plugin-testing.tpl.yml"
      }

      template {
        source = "local/bot-plugin-testing.tpl.yml"
        destination = "local/traefik-config/bot-plugin.yml"
      }

      # Plugin Challenge Template
      artifact {
        source = "https://raw.githubusercontent.com/pulibrary/princeton_ansible/${ var.branch_or_sha }/nomad/traefik-wall/deploy/challenge.tmpl.html"
        destination = "local/challenge.tmpl.html"
        mode = "file"
      }

      # Site Configuration.

      artifact {
        source = "https://raw.githubusercontent.com/pulibrary/princeton_ansible/${ var.branch_or_sha }/nomad/traefik-wall/deploy/sites/sites-production.yml"
        destination = "local/traefik-config"
      }

      resources {
        cpu    = 1000
        memory = 512
      }
    }
  }
}
