variable "branch_or_sha" {
  type = string
  default = "main"
}

job "traefik-wall-production" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  node_pool = "production"

  # Configure a Traefik node which will challenge everyone - we only expect this to turn on when under attack.
  group "traefik-high-challenge" {
    # Only one high challenge node, otherwise everyone gets captcha'd twice.
    count = 1

    update {
      canary = 1
      auto_promote = true
      auto_revert = true
    }

    network {
      port "http" { }
      port "traefik" { }
      port "metrics" { }

      dns {
        servers = ["10.88.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    service {
      name = "traefik-wall-production"
      tags = ["highchallenge", "node-${NOMAD_ALLOC_INDEX}"]
      canary_tags = ["canary"]
      port = "http"

      check {
        type = "http"
        port = "traefik"
        path = "/ping"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "traefik-wall-production-metrics"
      tags = ["highchallenge", "production", "metrics"]
      port = "metrics"
    }

    task "traefik" {
      driver = "podman"

      env {
        # Challenge after only 1 request.
        rate_limit = 1
        # Don't track IPs really, everyone's getting challenged.
        # This groups by xx.<>.<>.<>.<>
        subnet_mask = 8
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

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/traefik-wall-production" -}}
        CONSUL_HTTP_TOKEN = {{ .CONSUL_ACL_TOKEN }}
        {{- end -}}
        EOF
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
        source = "https://raw.githubusercontent.com/pulibrary/princeton_ansible/${ var.branch_or_sha }/nomad/traefik-wall/deploy/bot-plugin-production.tpl.yml"
      }

      template {
        source = "local/bot-plugin-production.tpl.yml"
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

  # Configure a Traefik node which will challenge everyone - we only expect this to turn on when under attack.
  group "traefik-dpul" {
    # Only one high challenge node, otherwise everyone gets captcha'd twice.
    count = 1

    update {
      canary = 1
      auto_promote = true
      auto_revert = true
    }

    network {
      port "http" { }
      port "traefik" { }
      port "metrics" { }

      dns {
        servers = ["10.88.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    service {
      name = "traefik-wall-production"
      tags = ["dpulchallenge", "node-${NOMAD_ALLOC_INDEX}"]
      canary_tags = ["canary"]
      port = "http"

      check {
        type = "http"
        port = "traefik"
        path = "/ping"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "traefik-wall-production-metrics"
      tags = ["dpulchallenge", "production", "metrics"]
      port = "metrics"
    }

    task "traefik" {
      driver = "podman"

      env {
        # Challenge after only 1 request.
        rate_limit = 1
        # Don't track IPs really, everyone's getting challenged.
        # This groups by xx.<>.<>.<>.<>
        subnet_mask = 8
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

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/traefik-wall-production" -}}
        CONSUL_HTTP_TOKEN = {{ .CONSUL_ACL_TOKEN }}
        {{- end -}}
        EOF
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
        source = "https://raw.githubusercontent.com/pulibrary/princeton_ansible/${ var.branch_or_sha }/nomad/traefik-wall/deploy/bot-plugin-dpul.tpl.yml"
      }

      template {
        source = "local/bot-plugin-dpul.tpl.yml"
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

  group "traefik" {
    count = 2

    update {
      canary = 1
      auto_promote = true
      auto_revert = true
    }

    network {
      port "http" { }
      port "traefik" { }
      port "metrics" { }

      dns {
        servers = ["10.88.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    service {
      name = "traefik-wall-production"
      tags = ["lowchallenge", "node-${NOMAD_ALLOC_INDEX}"]
      canary_tags = ["canary"]
      port = "http"

      check {
        type = "http"
        port = "traefik"
        path = "/ping"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "traefik-wall-production-metrics"
      tags = ["lowchallenge", "production", "metrics"]
      port = "metrics"
    }

    task "traefik" {
      driver = "podman"

      env {
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

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/traefik-wall-production" -}}
        CONSUL_HTTP_TOKEN = {{ .CONSUL_ACL_TOKEN }}
        {{- end -}}
        EOF
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
        source = "https://raw.githubusercontent.com/pulibrary/princeton_ansible/${ var.branch_or_sha }/nomad/traefik-wall/deploy/bot-plugin-production.tpl.yml"
      }

      template {
        source = "local/bot-plugin-production.tpl.yml"
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
