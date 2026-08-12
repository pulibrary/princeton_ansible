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

job "solr-staging" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "staging"
  priority = 80

  group "solr" {
    count = var.solr_count

    consul {}

    constraint {
      distinct_hosts = true
    }

    shutdown_delay = "10s"

    volume "data" {
      type   = "host"
      source = "solr"
      access_mode     = "single-node-single-writer"
      attachment_mode = "file-system"
      sticky = true
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
        servers = ["10.88.0.1", "128.112.129.209", "8.8.8.8", "8.8.4.4"]
      }
    }

    service {
      name = "solr-staging"
      port = "http"

      meta {
        alloc_index = "${NOMAD_ALLOC_INDEX}"
      }

      check {
        type = "http"
        port = "http"
        path     = "/solr/admin/info/health?requireHealthyCores=true"
        interval = "15s"
        timeout  = "5s"

        check_restart {
          limit = 5
          grace = "120s"
        }
      }
    }

    task "server" {
      driver = "podman"

      config {
        image = var.solr_image
        ports = ["http"]
      }

      restart {
        attempts = 5
        interval = "15m"
        delay    = "15s"
        mode     = "delay"
      }

      kill_timeout = "30s"

      template {
        destination = "local/solr.env"
        env         = true
        change_mode = "restart"

        data = <<-EOT
        ZK_HOST=zookeeper-staging.service.consul:2181
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
        destination = "/var/solr"
      }
    }
  }
}
