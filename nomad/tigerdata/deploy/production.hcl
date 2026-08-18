variable "branch_or_sha" {
  type = string
  default = "main"
}

job "tigerdata" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "service"
  node_pool = "all"

  group "deploy" {
    # Let's do two staging/two prod
    spread {
      attribute = "${node.pool}"
      weight    = 100
    }

    count = 6

    ephemeral_disk {
      size = 25000
    }

    service {
      name = "tigerdata-deploy"
      tags = ["logging"]
    }

    restart {
      attempts = 10
      delay = "5s"
      interval = "5m"
      mode = "delay"
    }

    reschedule {
      delay          = "30s"
      delay_function = "exponential"
      max_delay      = "120s"
      unlimited      = true
    }

    task "dind" {
      driver = "docker"
      user   = "root"

      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      config {
        image    = "docker:27-dind"
        cgroupns = "private"

        dns_servers = ["128.112.129.209", "8.8.8.8", "8.8.4.4"]

        cap_add = ["sys_admin", "net_admin", "mknod", "setfcap", "audit_write"]

        sysctl = {
          "net.ipv6.conf.all.disable_ipv6"     = "1"
          "net.ipv6.conf.default.disable_ipv6" = "1"
        }

        entrypoint = ["/bin/sh", "-c",
          "mount -o remount,bind,rw /proc/sys /proc/sys || echo 'REMOUNT FAILED' >&2; exec dockerd-entrypoint.sh --data-root=/alloc/docker --host=unix:///alloc/docker.sock --storage-driver=overlay2 --group=1500"]

        security_opt = [
          "seccomp=unconfined",
          "apparmor=unconfined",
        ]
      }

      env {
        DOCKER_TLS_CERTDIR = ""
      }

      resources {
        cpu    = 500
        memory = 1024
      }
    }

    task "deploy-runner" {
      driver = "docker"

      config {
        image = "ghcr.io/pulibrary/princeton_ansible-tigerdata-deployer:sha-${var.branch_or_sha}"

        network_mode = "container:dind-${NOMAD_ALLOC_ID}"

        shm_size = 1073741824

        entrypoint = ["/bin/sh", "-c",
          "until docker info >/dev/null 2>&1; do sleep 1; done; exec /opt/circleci/scripts/run.sh"]

        cpu_hard_limit = true
      }

      env {
        DOCKER_HOST = "unix:///alloc/docker.sock"
      }

      template {
        destination = "${NOMAD_SECRETS_DIR}/env.vars"
        env = true
        change_mode = "restart"
        data = <<EOF
        {{- with nomadVar "nomad/jobs/tigerdata" -}}
        CIRCLECI_RESOURCE_CLASS = pulibrary/tigerdata-deploy
        CIRCLECI_API_TOKEN = {{.CIRCLECI_API_TOKEN}}
        CIRCLECI_RUNNER_API_AUTH_TOKEN = {{.CIRCLECI_API_TOKEN}}
        CIRCLECI_RUNNER_NAME = "tigerdata-deployer-{{ env "NOMAD_ALLOC_INDEX" }}"
        CIRCLECI_RUNNER_CLEANUP_WORK_DIR = true
        CIRCLECI_RUNNER_MODE = "single-task"
        {{- end -}}
        EOF
      }

      resources {
        cpu    = 4000
        memory = 8192
      }
    }
  }
}
