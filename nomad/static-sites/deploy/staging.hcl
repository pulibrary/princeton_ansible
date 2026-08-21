variable "branch_or_sha" {
  type    = string
  default = "main"
}

job "static-sites-staging" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  node_pool   = "staging"

  group "web" {
    count = 2

    network {
      port "http" { to = 8080 }
    }

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
          X-Forwarded-Host = ["milberg-staging.lib.princeton.edu"]
        }
      }
    }

    # milberg
    service {
      name = "milberg-staging-web"
      port = "http"
    }
    # daviesproject
    service {
      name = "daviesproject-staging-web"
      port = "http"
    }
    # cicognara
    service {
      name = "cicognara-staging-web"
      port = "http"
    }
    # pcdm
    service {
      name = "pcdm-staging-web"
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
      # We have to do the root here instead of _site because there's symlinks under _site, and Nomad complains. It's happy to clone the whole repo.
      artifact {
        source      = "git::https://github.com/pulibrary/pcdm.org"
        destination = "local/sites/pcdm"
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
map $status $log_level {
    default "info";
    ~^4     "warn";
    ~^5     "error";
}

log_format json_combined escape=json
  '{"time":"$time_iso8601","remote_addr":"$remote_addr",'
  '"request":"$request","status":$status,'
  '"bytes":$body_bytes_sent,"user_agent":"$http_user_agent",'
  '"host":"$http_x_forwarded_host",'
  '"level":"$log_level",'
  '"message":"$remote_addr $request $status $body_bytes_sent"}';
map $http_x_forwarded_host $site_root {
    hostnames;
    default                              /srv/sites/none;
    # milberg
    milberg-staging.lib.princeton.edu    /srv/sites/milberg;
    # davies_project
    daviesproject-staging.lib.princeton.edu    /srv/sites/daviesproject;
    # cicognara
    cicognara-staging.lib.princeton.edu    /srv/sites/cicognara;
    # pcdm
    pcdm-staging.lib.princeton.edu    /srv/sites/pcdm/_site;
}
# Drop logs if it's from consul checks.
map $http_user_agent $loggable {
    ~*consul  0;
    default   1;
}
set_real_ip_from 172.20.80.13;
set_real_ip_from 172.20.80.14;
real_ip_header   X-Real-IP;
real_ip_recursive on;
server {
    listen 8080 default_server;
    root   $site_root;
    index  index.html index.htm;
    access_log /dev/stdout json_combined if=$loggable;

    location / {
        # Modified try_files to prevent redirection cycles
        try_files $uri $uri/ $uri.html $uri.xml =404;
    }

    # Prevent applying the XML extension multiple times
    location ~ \.xml$ {
        try_files $uri =404;
    }
}
EOF
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
