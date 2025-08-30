# mirror_sync

An opinionated Ansible role that sets up [pulmirror.princeton.edu](https://pulmirror.princeton.edu) to:

- Mirrors Node.js releases and Apache Solr via rsync (IPv4 only)
- Uses a single, resumable strategy: --partial --append-verify (no partial-dir)
- Installs & configures nginx to serve /mirror/ with directory listings
- Keeps mirrors fresh via cron 4×/day at :13 past 00, 06, 12, 18


## What it mirrors & serves

- Node.js: `rsync://unencrypted.nodejs.org/nodejs/release/` → `/var/www/htdocs/mirror/node/dist/`
- Apache Solr: `rsync.apache.org::apache-dist/solr/` → `/var/www/htdocs/mirror/apache/solr/`
- nginx serves: `https://pulmirror.princeton.edu/mirror/…` with directory listings (sizes in human-readable units, local timestamps)

### Requirements

Target hosts: OpenBSD (tested with OpenBSD 7.7)


Role layout
roles/mirror_artifacts/
├─ defaults/main.yml
├─ handlers/main.yml
├─ tasks/main.yml
├─ templates/nginx.conf.j2
├─ files/
│  ├─ pulmirror_princeton_edu_chained.pem        # public cert (plain)
│  └─ pulmirror_princeton_edu_priv.key           # private key (VAULTED)
└─ README.md

Variables (defaults)
```yaml
# Paths
web_root: /var/www/htdocs
mirror_root: /var/www/htdocs/mirror

# rsync (opinionated, IPv4 only; resume = append-verify)
mirror_base_flags: >
  -4 -rltH --safe-links --delete --delete-after
  --partial --append-verify
  --timeout=600 --contimeout=15 --no-motd

# Node.js mirror (always enabled)
nodejs_rsync_src: "rsync://unencrypted.nodejs.org/nodejs/release/"
nodejs_dest: "{{ mirror_root }}/node/dist"
nodejs_bwlimit: 0                # 0 = unlimited; set e.g. 20000 for ~20MB/s
nodejs_extra_opts: []            # e.g., ["--include='v*/'", "--exclude='*.pkg'"]
nodejs_cron_log: /var/log/rsync-nodejs.log

# Apache Solr mirror (always enabled)
solr_rsync_src: "rsync.apache.org::apache-dist/solr/"
solr_dest: "{{ mirror_root }}/apache/solr"
solr_bwlimit: 0
solr_extra_opts: []
solr_cron_log: /var/log/rsync-solr.log

# Cron (4×/day; not on the hour)
cron_minute: "13"
cron_hours:  "0,6,12,18"

# NGINX (TLS mandatory)
nginx_service_name: nginx
nginx_conf_path: /etc/nginx/nginx.conf

nginx_root: "{{ web_root }}"
nginx_mirror_uri_prefix: /mirror/
nginx_server_name: pulmirror.princeton.edu
nginx_listen_ipv4: 80
nginx_listen_ipv6: true
nginx_gzip: true
nginx_server_tokens_off: true
nginx_keepalive_timeout: 65
nginx_worker_processes: "auto"
nginx_worker_rlimit_nofile: 1024

# TLS (non-optional)
nginx_tls_port: 443
nginx_ssl_certificate: /etc/ssl/pulmirror_princeton_edu_chained.pem
nginx_ssl_certificate_key: /etc/ssl/private/pulmirror_princeton_edu_priv.key
nginx_ssl_session_timeout: 5m
nginx_ssl_session_cache: "shared:SSL:1m"
nginx_ssl_ciphers: >
  ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:
  ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:
  ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:
  ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:
  ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256
nginx_ssl_prefer_server_ciphers: true
```

**TLS files**

1. Place the public cert and the vaulted private key in the role:

```bash
roles/mirror_artifacts/files/pulmirror_princeton_edu_chained.pem
roles/mirror_artifacts/files/pulmirror_princeton_edu_priv.key   # vaulted
```

1. Vault the private key file:

```bash
ansible-vault encrypt roles/mirror_artifacts/files/pulmirror_princeton_edu_priv.key
# or create encrypted from scratch:
# ansible-vault create roles/mirror_artifacts/files/pulmirror_princeton_edu_priv.key
```

1. The role installs them to:

- Cert → `/etc/ssl/pulmirror_princeton_edu_chained.pem` (0644)
- Key → `/etc/ssl/private/pulmirror_princeton_edu_priv.key` (0600, directory 0700)


### Quick start

**Playbook:**

```yaml
- hosts: pulmirror
  become: true
  roles:
    - role: mirror_sync
  vars:
    nginx_server_name: pulmirror.princeton.edu
```


**Run:**

```bash
ansible-playbook mirror_sync.yml --ask-vault-pass
```


#### Operational details

- Resume behavior: `--partial --append-verify` ensures safe, efficient restarts. If disk fills, free space and re-run—rsync continues cleanly.
- IPv4 only: the role adds `-4` for reliability.
- Cron updates: 4×/day at `00:13, 06:13, 12:13, 18:13.` Logs:
  - `/var/log/rsync-nodejs.log`
  - `/var/log/rsync-solr.log`
- nginx config: serves `/mirror/` with `autoindex on`, human-readable sizes and local time. TLS is always configured/enabled.

#### Customizing

- Bandwidth cap
We've been sin-binned by upstream. If this happens. Set nodejs_bwlimit / solr_bwlimit in KiB/s. Example ~20 MB/s:

```yaml
nodejs_bwlimit: 20000
solr_bwlimit: 20000
```

License
MIT
