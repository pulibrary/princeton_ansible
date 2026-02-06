job "redis" {
  datacenters = ["dc1"]
  type        = "service"
  node_pool = "staging"

  group "cache" {
    network {
      port "db" { to = 6379 }
    }

    task "redis" {
      driver = "podman"

      config {
        image = "docker.io/library/redis:latest"
        ports = ["db"]
      }

      service {
        name = "redis"
        port = "db"
        
        check {
          name     = "alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
