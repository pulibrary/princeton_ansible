# httpd

Apache httpd on AlmaLinux/Rocky Linux with Entra ID logins through
[mod_auth_openidc](https://github.com/OpenIDC/mod_auth_openidc) and
Let's Encrypt certificates from certbot. It replaces the old
`mod_auth_cas` setup.

The role:

* installs `httpd`, `mod_ssl`, `mod_auth_openidc` and removes `mod_auth_cas`
* lays down a stock `httpd.conf` and a global-only `ssl.conf`
* writes a `:80` vhost that answers ACME challenges and redirects to https
* installs certbot from EPEL, issues a webroot certificate, enables
  `certbot-renew.timer` and reloads httpd after renewals
* writes a `:443` vhost plus one `<Directory>` per `httpd_directories` entry
* turns on `httpd_can_network_connect` so httpd can reach Entra ID, and
  opens http/https in firewalld

## Entra ID app registration

1. Register an app in the tenant (`httpd_oidc_tenant_id`).
2. Add a **Web** redirect URI: `https://<httpd_server_name>/oidc/redirect_uri`.
3. Create a client secret.
4. Put these in the group's vault:

```yaml
vault_httpd_oidc_client_id: "<application (client) id>"
vault_httpd_oidc_client_secret: "<client secret value>"
vault_httpd_oidc_crypto_passphrase: "<random string, encrypts session cookies>"
```

`REMOTE_USER` is the netid, taken from `preferred_username` with
`@princeton.edu` stripped, so `require_users` takes netids just like the
CAS config did.

The login uses the authorization code flow with PKCE (`S256`) plus the
client secret. Set `httpd_oidc_pkce_method: ""` to turn PKCE off.

### Certificate instead of a client secret

Set `httpd_oidc_client_auth: private_key_jwt` and httpd signs its token
requests with a key pair (OIDC `private_key_jwt`) instead of sending a
secret. This needs mod_auth_openidc >= 2.4.16.4, so EL9 or later. EL8's
2.4.9 can't send the `x5t` header Entra requires.

* The key pair comes from `roles/httpd/files/`, picked by `runtime_env`:
  `sandbox_oidc_private.key` / `sandbox_oidc_cert.crt` and
  `production_oidc_private.key` / `production_oidc_cert.crt`. Override with
  `httpd_oidc_private_key_src` and `httpd_oidc_certificate_src`.
  Create a pair and encrypt both files:

  ```bash
  cd roles/httpd/files
  openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days 730 \
    -subj "/CN=sandbox-dss1.lib.princeton.edu mod_auth_openidc" \
    -keyout sandbox_oidc_private.key -out sandbox_oidc_cert.crt
  devbox run -- ansible-vault encrypt --encrypt-vault-id pul \
    sandbox_oidc_private.key sandbox_oidc_cert.crt
  ```

* Upload the decrypted `<env>_oidc_cert.crt` under **Certificates & secrets** on the app
  registration. The play prints the thumbprint Entra should show.
* `vault_httpd_oidc_client_secret` is not needed. Delete the old secret
  from the app registration.
* The certificate expires (730 days above). Generate a new pair and upload
  the new certificate before then.

Log out with `https://<host>/oidc/redirect_uri?logout=https://<host>/`.

## Directories

```yaml
httpd_directories:
  - path: /data/Kaiko
    alias: /Kaiko
    directory_index: disabled
    oidc: true                       # Entra login required
    require_ip: [128.112.0.0/16]     # and must come from these networks
  - path: /data2/restricted/145
    alias: /AcademicTrace
    require_users: [netid1, netid2]  # only these netids
  - path: /var/www/html/private
    deny: true
```

All conditions on an entry are ANDed. See `defaults/main.yml` for every key.

## Certificates

Let's Encrypt is the default. For InCommon certificates through Certinext,
set the ACME server and the external account binding (EAB) credentials:

```yaml
httpd_certbot_acme_server: "https://acme-us.certinext.io/v1/directory"
httpd_certbot_eab_kid: "{{ vault_..._certinext_acme_eab_kid }}"
httpd_certbot_eab_hmac_key: "{{ vault_..._certinext_acme_eab_hmac_key }}"
```

The EAB credentials are only used the first time certbot registers its
account on the host. Renewals reuse that account.

The first run serves `:80` only, runs certbot, then adds the `:443` vhost.
DNS for every name in `httpd_certbot_domains` must point at the host and
port 80 must be reachable from the internet. To keep using an existing
certificate set `httpd_certbot_enabled: false` and point
`httpd_ssl_certificate_file`, `httpd_ssl_certificate_key_file` and
`httpd_ssl_ca_certificate_file` at it.

## Testing

```bash
cd roles/httpd && molecule test
```
