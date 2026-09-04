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
    * JSON log formatting (`LogFormat`, `LogFile`, `LogSPU`) - see Logging below.
    * Include files for IP blocking and allow lists (`princeton_allow.txt`).
2. **`/etc/GeoIP.conf`**: Configures the `geoipupdate` tool with MaxMind credentials.
3. **`/lib/systemd/system/ezproxy.service`**: Defines the systemd service for managing the EZproxy process.

## Logging

EZproxy's `LogFormat` and `LogSPU` directives take a free-form format string,
so EZproxy is told to write one JSON object per request instead of common log
format. The OpenTelemetry Collector (configured in `group_vars/ezproxy/`) then
reads named fields straight out of each line and forwards them to SigNoz, so
client IP, session, URL, status and country are queryable fields rather than
positions in a regex. Adding a field means editing the directive only, not also
rewriting a regex.

The files are `log/ezpYYYYMMDD.json` (all proxied requests) and
`log/spuYYYYMMDD.json` (starting point URLs). A daily cron script compresses
yesterday's files and deletes anything past `ezproxy_log_retention_days`; it
still handles the older `.log` files so any left on disk age out normally.

Two things worth knowing:

* `session_id` holds a session identifier rather than a username, because
  `config.txt` sets `Option LogSession` instead of `Option LogUser`. That is a
  deliberate privacy choice, so the field is named for what it actually holds.
* EZproxy does not escape quotes in the values it logs, so a request carrying a
  double quote in its user agent or URL can still produce a line that is not
  valid JSON. The Collector is set to forward those lines with their raw text
  intact instead of dropping them.

Audit logs (`audit/*.txt`) stay plain text and are still matched with a regex,
because EZproxy has no directive to change the audit log format.

**The running servers get `config.txt` from the encrypted
`files/{production,testing}_vault_config.txt`, not from `config.txt.j2`.** The
template is only used for a greenfield build, so a log format change has to be
made in both places to take effect. See the brownfield checklist below.

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

## Ansible playbook Tasks

We have a companion private :unamused: repository that administers [Ezproxy](https://github.com/PrincetonUniversityLibrary/ezproxy_conf). 

When we run the playbook on a brand new VM (greenfield scenario), the following tasks will be needed:

* [ ] run the `ezproxy.yml` playbook with tags for `all` and `never` to use the built-in `config.txt` file, which lets us then login to the admin UI and configure TLS certs (see below): 
`ansible-playbooks playbooks/ezproxy.yml --tags "all,never"`
* [ ] cap deploy from the ezproxy_config private repo (linked above) (`BRANCH=name bundle exec cap <environment> deploy`)
* [ ] log in as break-glass user with credentials in the `/var/local/ezproxy/user.txt` file to `http://ezproxy(-test).princeton.edu` (make sure to remove the 's' in https)
* [ ] update TLS certs (follow steps in [pul-it-handbook](https://github.com/pulibrary/pul-it-handbook/blob/main/services/ezproxy.md))

To make changes to an existing VM (brownfield scenario): 
* [ ] create a PR to files in the princeton_ansible repo with proposed changes
  * [ ] if making changes to the `config.txt` you will need to: 
    * [ ] decrypt `/roles/ezproxy/files/production_vault_config.txt` (or `.../testing_vault_config.txt` if on testing VM)
    * [ ] make your changes to the above file
    * [ ] encrypt the file and push changes
* [ ] from your branch, run the ezproxy playbook with NO tags:  
`ansible-playbook playbooks/ezproxy.yml`
* [ ] if needed, restart the ezproxy service: `sudo systemctl restart ezproxy`

### JSON log directives for the vault config

The encrypted `config.txt` files need these three lines to match
`templates/config.txt.j2`, otherwise EZproxy keeps writing common log format
and the Collector will forward every line unparsed:

```text
LogFormat {"timestamp":"%{%Y-%m-%dT%H:%M:%S%z}t","client_ip":"%h","session_id":"%u","http_method":"%m","url":"%U","virtual_host":"%v","http_protocol":"%{ezproxy-protocol}i","http_status":"%s","body_bytes_sent":"%b","duration_seconds":"%T","country_code":"%{Country()}e","user_agent":"%{user-agent}i","referer":"%{referer}i"}
LogFile -strftime log/ezp%Y%m%d.json
LogSPU -strftime log/spu%Y%m%d.json {"timestamp":"%{%Y-%m-%dT%H:%M:%S%z}t","client_ip":"%h","session_id":"%u","http_method":"%m","url":"%U","virtual_host":"%v","spu_access":"%{ezproxy-spuaccess}i","http_status":"%s","body_bytes_sent":"%b"}
```
