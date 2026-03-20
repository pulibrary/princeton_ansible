job "maintenant" {
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "sandbox"

  group "maintenant" {
    count = 1

    network {
      port "maintenant" {
        to = 8080
      }

      dns {
        servers = ["10.88.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    ephemeral_disk {
      size    = 1024
      sticky  = true
      migrate = true
    }

    service {
      name = "maintenant"
      port = "maintenant"

      check {
        type     = "http"
        port     = "maintenant"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "maintenant" {
      driver = "podman"
      user   = "root"

      env {
        MAINTENANT_ADDR = "0.0.0.0:8080"
        MAINTENANT_DB   = "${NOMAD_ALLOC_DIR}/data/maintenant.db"
        DOCKER_HOST     = "unix:///run/podman/podman.sock"
      }

      config {
        image = "ghcr.io/kolapsis/maintenant:latest"
        ports = ["maintenant"]

        volumes = [
          "/run/podman/podman.sock:/run/podman/podman.sock:rw",
        ]
      }

      resources {
        cpu    = 500
        memory = 512
      }

      restart {
        attempts = 10
        interval = "5m"
        delay    = "25s"
        mode     = "delay"
      }
    }
  }
}
