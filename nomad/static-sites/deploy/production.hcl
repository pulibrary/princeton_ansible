variable "branch_or_sha" {
  type    = string
  default = "main"
}

job "static-sites-production" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "production"

  group "web" {
    count = 2

    network {
      port "http" { to = 8080 }
    }

    # This is the health endpoint, that determines if nginx is running
    service {
      port = "http"
      tags = ["logging"]
      check {
        type     = "http"
        port     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
        header {
          X-Forwarded-Host = ["milberg.lib.princeton.edu"]
        }
      }
    }

    # milberg
    service {
      name = "milberg-production-web"
      port = "http"
    }
    # daviesproject
    service {
      name = "daviesproject-production-web"
      port = "http"
    }
    # cicognara
    service {
      name = "cicognara-production-web"
      port = "http"
    }

    task "nginx" {
      driver = "docker"

      user = "101:101"

      # Pull from github.
      artifact {
        source      = "git::https://github.com/pulibrary/milberg_exhibit_archive//_site"
        destination = "local/sites/milberg"
      }
      artifact {
        source      = "git::https://github.com/pulibrary/davies_project//_site"
        destination = "local/sites/daviesproject"
      }
      artifact {
        source      = "git::https://github.com/pulibrary/digital-cicognara-library//apps/cicognara-static/_site"
        destination = "local/sites/cicognara"
      }

      config {
        image = "docker.io/nginxinc/nginx-unprivileged:stable"
        # Force Docker to re-pull the image when the job re-deploys, which should be every week when the boxes reboot.
        # Should keep us auto-updated.
        force_pull = true

        ports = ["http"]

        volumes = [
          "local/sites:/srv/sites:ro",
          "local/nginx/sites.conf:/etc/nginx/conf.d/default.conf:ro",
        ]

        readonly_rootfs = true
        cap_drop        = ["ALL"]
        security_opt    = ["no-new-privileges"]
        mount {
          type = "tmpfs"
          target = "/tmp"
        }
        mount {
          type = "tmpfs"
          target = "/var/cache/nginx"
        }
        mount {
          type = "tmpfs"
          target = "/var/run"
        }
      }

      template {
        destination = "local/nginx/sites.conf"
        change_mode = "restart"
        data        = <<EOF
map $http_x_forwarded_host $site_root {
    hostnames;
    default                              /srv/sites/none;
    # milberg
    milberg.lib.princeton.edu    /srv/sites/milberg;
    # davies_project
    daviesproject.princeton.edu    /srv/sites/daviesproject;
    daviesproject.lib.princeton.edu    /srv/sites/daviesproject;
    # cicognara
    cicognara.org    /srv/sites/cicognara;
}

server {
    listen 8080 default_server;
    root   $site_root;
    index  index.html index.htm;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF
      }

      resources {
        cpu    = 1000
        memory = 1024
      }
    }
  }
}
