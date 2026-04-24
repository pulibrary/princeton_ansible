# pulmirror

An Ansible role to provision a FreeBSD-based mirror host with:  

- nginx (HTTPS-enabled)  
- ACME certificates via lego (DNS-01 using DNSimple)  
- Automated certificate renewal  
- Node.js distribution mirror (wget-based)  
- Log rotation and scheduled sync  

---  

## Requirements

- FreeBSD host  
- DNS hosted in DNSimple (or delegated for DNS-01)  
- DNSimple API token with access to the zone  
- Ansible with `community.general` collection  

```bash  
ansible-galaxy collection install community.general
```

---

## What this role does

### TLS (lego + DNSimple)

- Uses lego with DNS-01 challenge
- Stores certs under:

  ```sh
  /usr/local/etc/lego/certificates/
  ```

- Automatically renews via cron
- Reloads nginx on renewal

### nginx

- Installs nginx
- Creates:

  ```sh
  /usr/local/etc/nginx/conf.d/
  ```

- Ensures `nginx.conf` includes:

  ```sh
  include /usr/local/etc/nginx/conf.d/*.conf;
  ```

- Configures HTTP → HTTPS redirect
- Serves either static content or reverse proxy

### Node.js mirror

- Mirrors:

  ```sh
  https://nodejs.org/dist/
  ```

- Stores content under:

  ```sh
  /usr/local/www/nginx-dist/mirror/nodejs
  ```

- Uses `wget --mirror`
- Runs via cron
- Uses lockfile to prevent concurrent runs
- Rotates logs via `newsyslog`

---

## Variables

### Core

```yaml
pulmirror_domain: "example.org"  
pulmirror_domains:  

- "example.org"  

pulmirror_email: "admin@example.org"
```

### ACME / DNSimple

```yaml
pulmirror_dns_provider: "dnsimple"  
pulmirror_dnsimple_oauth_token: "{{ vault_dnsimple_oauth_token }}"  
pulmirror_dnsimple_ttl: 300  
```

### Paths

```yaml
pulmirror_path: "/usr/local/etc/lego"  

pulmirror_ssl_certificate: "/usr/local/etc/lego/certificates/<domain>.crt"  
pulmirror_ssl_certificate_key: "/usr/local/etc/lego/certificates/<domain>.key"  

pulmirror_nginx_conf: "/usr/local/etc/nginx/conf.d/<domain>.conf"
```

### Node mirror

```yaml
nodejs_mirror_root: /usr/local/www/nginx-dist/mirror/nodejs  
nodejs_mirror_source: https://nodejs.org/dist/  

nodejs_mirror_cron_hour: "*/6"  
nodejs_mirror_cron_minute: "17"
```

---

## Example

```yaml
- hosts: pulmirror_staging  
  become: true  
  roles:  

  - role: pulmirror  
    vars:  
      pulmirror_domain: "pultestmirror.pulcloud.io"  
      pulmirror_domains:  

        - "pultestmirror.pulcloud.io"  

      pulmirror_email: "lsupport@princeton.edu"  
      pulmirror_use_staging: true  

      pulmirror_dnsimple_oauth_token: "{{ vault_dnsimple_oauth_token }}"
```

---

## Troubleshooting

### Certificate issuance fails

Run manually on host:

set -a  
. /usr/local/etc/lego-dnsimple.env  
set +a  

lego --dns dnsimple ...

Common issues:

- Token lacks access to DNS zone
- Wrong domain (zone mismatch)
- Missing DNS delegation for `_acme-challenge`

---

### DNS-01 caveat

ACME validation happens at:

_acme-challenge.<domain>

If your public name is:

pultestmirror.princeton.edu

but DNS is hosted in:

pulcloud.io

you must either:

- issue cert for `pulcloud.io` name  
  **or**
- delegate `_acme-challenge` via CNAME

---

## Notes

- Role is FreeBSD-specific
- Uses `pkg` (not apt/yum)
- nginx runs as `www`
-

```text
```
