# EZproxy

This role installs and configures [OCLC EZproxy](https://www.oclc.org/en/ezproxy.html) on Linux servers (specifically targeting Ubuntu/Debian based systems). It handles binary installation, dependency management, SSL certificate generation via Certbot (Snap), GeoIP updates, and systemd service configuration.

## Requirements

* **Operating System:** Ubuntu/Debian (requires `apt`).
* **Network:** Outbound access to:
  * OCLC servers (for WSKey validation).
  * MaxMind (for GeoIP updates).
  * Sectigo/ACME (for SSL certificates).
* **Snapd:** The target machine requires `snapd` installed and enabled (handled by the role, but `systemd` must be present).

## Role Variables

Available variables are listed below, along with default values (see `defaults/main.yml`).

### General Configuration

| Variable | Default | Description |
| :--- | :--- | :--- |
| `host_name` | `ezproxy-test.princeton.edu` | The public hostname for the EZproxy server. |
| `ezproxy_host` | `localhost` | Internal server name reference. |
| `systems_user` | `deploy` | The system user for administration. |
| `deploy_user` | *Required* | The user who owns the EZproxy files and processes (usually `deploy` at PUL ). |
| `oclc_wskey` | `12345` (Vaulted) | The WSKey provided by OCLC to authorize the EZproxy installation. |

### Shibboleth / SAML (Entra ID)

| Variable | Default | Description |
| :--- | :--- | :--- |
| `microsoft_entra_idp_uuid` | `981dbab5...` | UUID for the Microsoft Entra IDP. |
| `microsoft_entra_app_uuid` | `1b833779...` | UUID for the specific Entra application. |
| `shib_admin_user` | `[]` | List of admin users for Shibboleth contexts. |

### Secrets & Credentials (Vaulted)

These variables usually come from an Ansible Vault and are required for specific tasks.

| Variable | Description |
| :--- | :--- |
| `vault_acme_eab_kid` | Key ID for Sectigo/InCommon ACME account. |
| `vault_acme_eab_hmac_key` | HMAC key for Sectigo/InCommon ACME account. |
| `geolite2_account_id` | Account ID for MaxMind GeoIP updates. |
| `geolite2_license_key` | License Key for MaxMind GeoIP updates. |

## Dependencies

* **Certbot:** Installed via `snap` with classic confinement.
* **GeoIP:** Installs `geoipupdate` and configures a cron job for daily updates.

## Configuration Files

The role deploys the following key configuration files:

1. **`/var/local/ezproxy/config.txt`**: The main EZproxy configuration. It is templated to include settings for:
    * Load balancer handling (`LoginPort 80`, `Option ProxyByHostname`).
    * Shibboleth Metadata (currently commented out in template, typically configured here).
    * Security options (Audit levels, Intruder blocking).
    * Log formatting (`LogFormat`, `LogFile`).
    * Include files for IP blocking and allow lists (`princeton_allow.txt`).
2. **`/etc/GeoIP.conf`**: Configures the `geoipupdate` tool with MaxMind credentials.
3. **`/lib/systemd/system/ezproxy.service`**: Defines the systemd service for managing the EZproxy process.

## Example Playbook

```yaml
- hosts: ezproxy_servers
  become: true
  vars:
    deploy_user: deploy
    host_name: ezproxy.example.edu
    oclc_wskey: "{{ my_vaulted_wskey }}"
    # MaxMind Credentials
    geolite2_account_id: "123456"
    geolite2_license_key: "abcdef123456"
    # ACME Credentials
    vault_acme_eab_kid: "kid_1"
    vault_acme_eab_hmac_key: "key_1"

  roles:
    - role: ezproxy
```

## Firewall Rules (UFW)

The role automatically configures UFW to allow:

    * 80/tcp (HTTP)
    * 443/tcp (HTTPS)
    * 6556/tcp (CheckMK monitoring agent) - restricted to source 128.112.0.0/16.

## Post Ansible playbook Tasks

We have a companion private :unamused: repository that administers [Ezproxy](https://github.com/PrincetonUniversityLibrary/ezproxy_conf). When the run completes on a brand new VM the following tasks will be needed:

* [ ] cap deploy (`BRANCH=name bundle exec cap <environment> deploy`) from the repo above
* [ ] login as break-glass user (remove the 's' in https)
* [ ] update TLS certs (follow steps in [pul-it-handbook](https://github.com/pulibrary/pul-it-handbook/blob/main/services/ezproxy.md))
* [ ] change the following files
  * [ ] in `config.txt`: uncomment `# LoginPortSSL 443` & `# Option ForceHTTPSLogin`
  * [ ] in `config.txt`: remove `ShibbolethDisable2.0` (line 20)
  * [ ] in `config.txt`: uncomment everything under `ShibbolethMetadata /`(lines 22-27)
  * [ ] in `config.txt`: uncomment IncludeFiles, lines 62-64, 66, 68
* [ ] restart the ezproxy service: `sudo systemctl restart ezproxy`
