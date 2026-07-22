# step_ca

Builds and runs the Smallstep [`step-ca`](https://smallstep.com/docs/step-ca)
certificate authority on `step-ca.lib.princeton.edu`, backed by Microsoft
Entra ID OIDC, issuing short-lived SSH user certificates. Targets Ubuntu.

This role has a tight coupling with the [ssh_ca_trust](../ssh_ca_trust) role, which configures the SSH hosts that
accept the resulting certificates.

## What it does

1. Adds the Smallstep apt repo and installs `step-cli` + `step-ca`.
2. Creates the `step` system user and the `$STEPPATH` tree at `/etc/step-ca`.
3. Runs `step ca init --ssh` **once** — creating the root + intermediate CAs,
   the SSH host and user CA keys, and a break-glass JWK provisioner.
4. Installs an SSH user-certificate template: principals are fixed to
   `step_ca_ssh_principals` (default `pulsys`) and the cert `KeyID` carries the
   authenticating Entra user's email for audit.
5. Installs the upstream **hardened** systemd unit and enables the daemon.
6. Merges an Entra OIDC provisioner into `ca.json` on every run — idempotently.

## OIDC merge behaviour

The OIDC provisioner is merged into `authority.provisioners` directly, not via
`step ca provisioner add`. On each run the role:

- replaces the entry named `step_ca_oidc_provisioner_name` **in place** (or
  appends it if absent), preserving any fields step-ca itself added;
- leaves every other provisioner (notably the break-glass JWK) untouched;
- rewrites `ca.json` **only when the merged result differs** (a clean converge
  reports `ok`), backing up the previous file, then reloads via `SIGHUP`.

So changing the client secret or endpoint in Vault re-applies on the next run;
a no-op run changes nothing.

## Required Vault variables

```yaml
step_ca_password: "…"                 # encrypts the CA keys
# when step_ca_oidc_enabled: true
step_ca_oidc_tenant_id: "2ff60116-7431-425d-b5af-077d7791bda4"
step_ca_oidc_client_id: "…"
step_ca_oidc_client_secret: "…"       # vault
```

## Entra app registration

The role assumes the Entra app is already registered. For reference,
the working configuration is:

- Redirect URI `http://127.0.0.1:10000` under a public-client platform —
  matches `step_ca_oidc_listen_address`.
- API permissions: `openid`, `profile`, `email`, `User.Read`
  (+ `GroupMember.Read.All` for group claims).
- Token configuration: `email` claim on the id_token; optional groups claim
  (Security groups, emitted as Group ID).
- Admin consent granted.

To restrict access to specific Entra security groups, set their object IDs:

```yaml
step_ca_oidc_groups:
  - "00000000-0000-0000-0000-000000000000"
```

## Example play

```yaml
- hosts: step_ca
  roles:
    - role: step_ca
      vars:
        step_ca_oidc_enabled: true
```

After the first converge the role prints the SSH User CA public key. Copy it
into `group_vars/all` as `ssh_ca_user_ca_public_key` for the [ssh_ca_trust](../ssh_ca_trust)
role.

## Notes & caveats

- `step ca init` runs once, guarded by `ca.json`; to re-key you must remove
  `/etc/step-ca` deliberately. The role never clobbers an existing CA.
- `--deployment-type=standalone` keeps init non-interactive on current
  step-cli
- The hardened unit sets `ProtectSystem=full` and only
  `ReadWritePaths=/etc/step-ca/db`. If you relocate `$STEPPATH` or the badger
  DB, update the unit accordingly.
- The `step ca init` flag set is version-sensitive
- Molecule's `default` scenario builds the CA with OIDC disabled (no Entra
  round-trip) and needs network at converge to install packages.

## HA later

Two `step-ca` nodes sharing **one** root/intermediate and a shared PostgreSQL
backend behind an NGINX Plus VIP — never two independent roots behind one VIP.
