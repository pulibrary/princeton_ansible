job "reservoir" {
    region = "global"
    datacenters = ["dc1]
    type = "service"
    node_pool = "all"

    group "grist-all" {
        count = 1

        network {
            mode = "host"
            port "http" {
                static = 8081
            }
        }
    }

    task "reservoir" {
        driver = "docker"

        config {
            image = "ghcr.io/pulibrary/reservoir-jit:latest-02-27-2026"
            network_mode = "host"
        }
    }

    resources {
        cpu = 2000
        memory = 2048
    }
}
