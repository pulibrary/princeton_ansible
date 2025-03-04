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
        source = "https://raw.githubusercontent.com/pulibrary/princeton_ansible/${ var.branch_or_sha }/nomad/traefik-wall/deploy/bot-plugin-staging.tpl.yml"
      }

      template {
        source = "local/bot-plugin-staging.tpl.yml"
        destination = "local/traefik-config/bot-plugin.yml"
      }

      # Plugin Challenge Template
      artifact {
        source = "https://raw.githubusercontent.com/pulibrary/princeton_ansible/${ var.branch_or_sha }/nomad/traefik-wall/deploy/challenge.tmpl.html"
        destination = "local/challenge.tmpl.html"
        mode = "file"
      }

      # Site Configuration. Add an artifact per site.

      # LAE Configuration
      artifact {
        source = "https://raw.githubusercontent.com/pulibrary/princeton_ansible/${ var.branch_or_sha }/nomad/traefik-wall/deploy/sites/lae-staging.yml"
        destination = "local/traefik-config"
      }

      resources {
        cpu    = 1000
        memory = 512
      }
    }
  }
}
