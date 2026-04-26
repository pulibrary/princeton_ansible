# Lego

Installs and configures [Lego](https://www.google.com/search?q=https://go-acme.github.io/lego/), a Let's Encrypt client and ACME library, specifically tailored for  our **FreeBSD** systems (using `pkgng`).

It manages certificate issuance via the HTTP-01 challenge, handles automated renewals via cron, and provides a "bootstrap" feature to generate self-signed certificates so that our [OpenResty/Nginx](../openresty) can start before the real certificates are issued.

> Note: This role has a tight coupling with the [OpenResty Role](../openresty) and expects it

## Requirements

- **FreeBSD**: This role uses `pkgng` and paths common to FreeBSD (like `/usr/local/etc`).

- **OpenResty/Nginx**: Designed to work alongside a web server configured to serve the `.well-known/acme-challenge/` directory from the defined webroot.

## Role Variables

Available variables are listed below, along with default values (see `defaults/main.yml`):

| **Variable**                 | **Default**                 | **Description**                                                                       |
| ---------------------------- | --------------------------- | ------------------------------------------------------------------------------------- |
| `lego_package`               | `lego`                      | The name of the package to install.                                                   |
| `lego_email`                 | `""`                        | **Required.** The email address associated with the ACME account.                     |
| `lego_data_dir`              | `/var/db/lego`              | Directory where Lego stores account data and certificates.                            |
| `lego_cert_dir`              | `/var/db/lego/certificates` | Final destination for `.crt` and `.key` files.                                        |
| `lego_webroot`               | `/usr/local/www/acme`       | Path used for HTTP-01 challenges.                                                     |
| `lego_acme_server`           | `staging`                   | ACME directory URL or shorthand. Set to `null` or empty for Let's Encrypt Production. |
| `lego_key_type`              | `ec384`                     | Key type to generate (e.g., `rsa2048`, `ec256`, `ec384`).                             |
| `lego_renew_days`            | `30`                        | Number of days before expiry to attempt renewal.                                      |
| `lego_renew_hook`            | `service openresty reload`  | Command executed after a successful certificate renewal.                              |
| `lego_renew_log`             | `/var/log/lego-renew.log`   | Path to the renewal script log file.                                                  |
| `lego_bootstrap_self_signed` | `true`                      | Generate temporary self-signed certs if real ones don't exist.                        |
| `lego_certificates`          | `[]`                        | List of certificates to manage (see Example below).                                   |

### The `lego_certificates` List

Each item in the list should follow this structure:

```yaml
lego_certificates:
  - primary: "example.com"                # Used for filename (defaults to first domain)
    domains: ["example.com", "www.example.com"] 
```

## How It Works

1. **Installation**: Installs the `lego` package via `pkgng`.

2. **Bootstrapping**: If `lego_bootstrap_self_signed` is true, it creates a self-signed cert/key pair for every entry in `lego_certificates`. This prevents web servers from failing to start due to missing files.

3. **Renewal Script**: Deploys a wrapper script to `/usr/local/sbin/lego-renew.sh`. This script checks for existing Lego metadata; if missing, it performs an initial `run` (issuance). If present, it performs a `renew`.

4. **Automation**: Sets up a cron job to run the renewal script daily.

## Example Playbook


```yaml
- hosts: loadbalancers
  vars:
    lego_email: "admin@example.com"
    lego_acme_server: "" # Use production
    lego_certificates:
      - primary: "app.example.com"
        domains:
          - "app.example.com"
          - "assets.example.com"
  roles:
    - role: lego
    - role: openresty
```

## OpenResty/Nginx Configuration Hint

To use the HTTP-01 challenge, ensure your web server configuration includes a block similar to this:


```nginx
server {
    listen 80;
    server_name .example.com;

    location /.well-known/acme-challenge/ {
        alias /usr/local/www/acme/.well-known/acme-challenge/;
    }
}
```

## License

MIT-0
