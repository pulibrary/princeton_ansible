variable "branch_or_sha" {
  type    = string
  default = "main"
}

variable "solr_image" {
  type    = string
  default = "quay.io/pulibrary/ci-solr:9.9-v1.0.2"
}

variable "solr_count" {
  type    = number
  default = 3
}

variable "solr_heap" {
  type    = string
  default = "1g"
}

job "solr-sandbox" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "sandbox"
  # Higher priority because this job only runs on nodes with provisioned
  # storage, so it needs to push other jobs off of them.
  priority = 80

  group "solr" {
    count = var.solr_count

    consul {}

    constraint {
      distinct_hosts = true
    }

    shutdown_delay = "10s"

    volume "data" {
      type            = "host"
      source          = "solr-sandbox"
      access_mode     = "single-node-single-writer"
      attachment_mode = "file-system"
      sticky          = true
    }

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "30s"
      healthy_deadline = "5m"
      auto_revert      = false
    }

    network {
      port "http" { static = 8983 }

      dns {
        servers = ["172.17.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    service {
      name = "solr-sandbox"
      port = "http"
      tags = ["logging"]

      meta {
        alloc_index = "${NOMAD_ALLOC_INDEX}"
      }

      check {
        type     = "http"
        port     = "http"
        path     = "/solr/admin/info/health?requireHealthyCores=true"
        interval = "15s"
        timeout  = "5s"

        check_restart {
          limit = 5
          grace = "120s"
        }
      }
    }

    task "await-zookeeper" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      consul {}

      config {
        image       = "busybox:1.37"
        entrypoint  = ["/bin/sh", "-c"]
        args        = ["until nc -z \"$ZK_ADDRESS\" \"$ZK_PORT\"; do echo 'waiting for zookeeper'; sleep 5; done"]
        extra_hosts = ["host.docker.internal:host-gateway"]
      }

      template {
        destination = "local/zk.env"
        env         = true
        change_mode = "restart"

        data = <<-EOT
        {{- range $index, $s := service "zookeeper-sandbox" }}
        {{- if eq $index 0 }}
        ZK_ADDRESS={{ $s.Address }}
        ZK_PORT={{ $s.Port }}
        {{- end }}
        {{- end }}
        EOT
      }

      resources {
        cpu    = 50
        memory = 64
      }
    }

    task "server" {
      driver = "docker"
      # Matches the solr user baked into the image, and the ownership of the
      # host volume, so we never run as root.
      user = "8983:8983"

      config {
        image       = var.solr_image
        ports       = ["http"]
        extra_hosts = ["host.docker.internal:host-gateway"]
      }

      consul {}

      restart {
        attempts = 5
        interval = "15m"
        delay    = "15s"
        mode     = "delay"
      }

      kill_timeout = "30s"

      # Point at every zookeeper in the ensemble, discovered through Consul, so
      # that solr can keep running if any single zookeeper is unavailable.
      template {
        destination = "local/solr.env"
        env         = true
        change_mode = "restart"

        wait {
          min = "10s"
          max = "30s"
        }

        splay = "90s"

        data = <<-EOT
        ZK_HOST={{ range $index, $s := service "zookeeper-sandbox" }}{{ if gt $index 0 }},{{ end }}{{ $s.Address }}:{{ $s.Port }}{{ end }}
        ZK_CLIENT_TIMEOUT=30000
        SOLR_PORT={{ env "NOMAD_PORT_http" }}
        SOLR_HOST={{ env "NOMAD_IP_http" }}
        SOLR_JETTY_HOST=0.0.0.0
        SOLR_HEAP=${var.solr_heap}
        SOLR_OPTS=-Dsolr.sharedLib=/opt/solr/lib
        SOLR_MODULES=scripting,langid
        SOLR_SECURITY_MANAGER_ENABLED=false
        EOT
      }

      resources {
        cpu    = 2000
        memory = 3072
      }

      volume_mount {
        volume      = "data"
        destination = "/var/solr/data"
      }
    }
  }
}
