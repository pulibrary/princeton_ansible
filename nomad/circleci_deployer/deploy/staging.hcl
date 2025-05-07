variable "branch_or_sha" {
  type = string
  default = "main"
}

job "circleci-runner" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  node_pool = "staging"

  group "deploy" {
    # Only one high challenge node, otherwise everyone gets captcha'd twice.
    count = 1

    network {
      port "http" { to=7623 }

      dns {
        servers = ["10.88.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    service {
      name = "circleci-runner"
      port = "http"

      check {
        name     = "ready"
        type     = "http"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
        path     = "/ready"
      }
    }

    task "deploy-runner" {
      driver = "podman"

      config {
        image = "ghcr.io/pulibrary/princeton_ansible-circleci-deployer:${ var.branch_or_sha }"
        ports = ["http"]
      }
      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/circleci-runner" -}}
        CIRCLECI_RESOURCE_CLASS = pulibrary/ruby-deploy
        CIRCLECI_API_TOKEN = {{.CIRCLECI_API_TOKEN}}
        {{- end -}}
        EOF
      }
      resources {
        cpu    = 4000
        memory = 2048
      }
    }
  }
}
