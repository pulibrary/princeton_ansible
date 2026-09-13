variable "branch_or_sha" {
  type    = string
  default = "main"
}

variable "zookeeper_version" {
  type    = string
  default = "3.9"
}

variable "zookeeper_count" {
  type    = number
  default = 3
}

job "zookeeper-sandbox" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "sandbox"
  # Higher priority because this job only runs on nodes with provisioned
  # storage, so it needs to push other jobs off of them.
  priority = 80

  group "zookeeper" {
    count = var.zookeeper_count

    consul {}

    constraint {
      distinct_hosts = true
    }

    volume "data" {
      type            = "host"
      source          = "zookeeper-sandbox"
      access_mode     = "single-node-single-writer"
      attachment_mode = "file-system"
      sticky          = true
    }

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "15s"
      healthy_deadline = "5m"
      auto_revert      = false
    }

    network {
      port "client" { static = 2181 }
      port "peer" { static = 2888 }
      port "leader" { static = 3888 }

      dns {
        servers = ["172.17.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    service {
      name = "zookeeper-sandbox"
      port = "client"
      tags = ["logging"]

      meta {
        alloc_index = "${NOMAD_ALLOC_INDEX}"
      }

      check {
        type     = "script"
        name     = "zk-serving"
        task     = "server"
        command  = "/bin/bash"
        args     = ["-c", "zkServer.sh status"]
        interval = "20s"
        timeout  = "5s"
      }
    }

    task "server" {
      driver = "docker"
      # Matches the zookeeper user baked into the image, and the ownership of
      # the host volume, so we never run as root.
      user = "1000:1000"

      config {
        image       = "zookeeper:${var.zookeeper_version}"
        ports       = ["client", "peer", "leader"]
        extra_hosts = ["host.docker.internal:host-gateway"]
      }

      restart {
        attempts = 5
        interval = "15m"
        delay    = "15s"
        mode     = "delay"
      }

      # Each node needs to know about every other node in the ensemble. We use
      # the Consul service registration to discover peers, and the allocation
      # index (plus one) as the stable zookeeper id.
      template {
        destination = "local/zoo.env"
        env         = true
        change_mode = "restart"

        wait {
          min = "10s"
          max = "30s"
        }

        splay = "90s"

        data = <<-EOT
        ZOO_MY_ID={{ env "NOMAD_ALLOC_INDEX" | parseInt | add 1 }}
        ZOO_STANDALONE_ENABLED=false
        ZOO_4LW_COMMANDS_WHITELIST=srvr,ruok,mntr
        ZOO_AUTOPURGE_PURGEINTERVAL=1
        ZOO_SERVERS="server.{{ env "NOMAD_ALLOC_INDEX" | parseInt | add 1 }}=0.0.0.0:2888:3888;2181 {{ range $s := service "zookeeper-sandbox|any" }}{{ if and $s.ServiceMeta.alloc_index (ne $s.ServiceMeta.alloc_index (env "NOMAD_ALLOC_INDEX")) }}server.{{ $s.ServiceMeta.alloc_index | parseInt | add 1 }}={{ $s.Address }}:2888:3888;2181 {{ end }}{{ end }}"
        EOT
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      volume_mount {
        volume      = "data"
        destination = "/data"
      }
    }
  }
}
