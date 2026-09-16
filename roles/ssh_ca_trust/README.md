# ssh_ca_trust

Configures an SSH host to accept certificates signed by the `step_ca` SSH
**User** CA. The host never talks to step-ca or Entra — it is a relying party
that trusts a static public key. No secrets are involved, so this role is safe
to apply broadly and is a good candidate to fold into the `common` role once
the SSH-CA pilot graduates.

See [AUTH_FLOW.md](AUTH_FLOW.md) for diagrams of how a certificate is issued,
how sshd verifies it offline, and how a password-only service account is scoped
to a single `Match User` block.

## What it does

1. Installs `openssh-server`.
2. Writes the User CA public key to `/etc/ssh/trusted_user_ca_keys.pem`
   (optionally asserting `ssh_ca_user_ca_fingerprint`).
3. Creates local users and their `/etc/ssh/auth_principals/%u` files.
4. Drops `60-ssh-ca-access.conf` into `sshd_config.d`.
5. Optionally re-enables password authentication for named service accounts
   inside a `Match User` block, leaving the host password-less for everyone
   else.
6. Validates `sshd -t` **before** restarting (handler ordering guarantees a
   bad config never triggers a restart).
7. Warns if `AllowUsers`/`AllowGroups` could silently block cert logins — this
   was the final blocker on both pilot hosts.

## Variables

```yaml
# Shared data — define once in group_vars/all (printed by the step_ca role):
ssh_ca_user_ca_public_key: "ssh-ed25519 AAAA… ssh_user_ca_key"
ssh_ca_user_ca_fingerprint: "SHA256:uFSXrhpueJZ1NT5j36Hf6BeAsV0Ssx+ZOR74oRymIqM"

ssh_ca_operator_group: pulsys
ssh_ca_allowed_users:
  - pulsys
  - alice
ssh_ca_users:
  - name: alice
    principals:
      - alice@princeton.edu
    # Set an empty list for an ordinary, non-admin local Unix account.
    groups: []
    # create_local_user defaults to true

# Accounts allowed to authenticate with a password as well as a certificate.
ssh_ca_password_auth_users:
  - veeam-service
```

## Password authentication for service accounts

The host default is `PasswordAuthentication no`. Some service accounts cannot
present a certificate — the Veeam backup appliance on the Proxmox nodes is the
current example — so list them in `ssh_ca_password_auth_users`. The role emits a
`Match User` block that turns password and keyboard-interactive authentication
back on for just those accounts, then closes with `Match all` so nothing parsed
after the include is accidentally scoped to the match. Those accounts are also
folded into `AllowUsers` when that list is in use, so a host-level restriction
cannot silently block them.

This is the supported alternative to flipping `ssh_ca_disable_password_auth` to
`false`, which re-opens password logins for the whole host.

The role never stores or sets a password. The account's password must be checked
locally or by a directory that answers PAM, so pair it with `ad_join`
(realm-joined Active Directory) or `sssd_ldap` (Active Directory over LDAPS, no
join) when the account is not local. Keyboard-interactive is enabled alongside
password because sssd prompts through PAM.

When the identity source uses UPN-style logins (`svc@princeton.edu`), list every
form users actually type, since `Match User` compares the literal name supplied
at login.

Password-only service accounts cannot use `entraid_join`: Himmelblau forces MFA
on every remote session, so the login fails even with the correct password.

On the Proxmox nodes sshd is only the first layer Veeam has to get through; the
[veeam_proxmox](../veeam_proxmox) role covers sudo and the Proxmox API.

## Password and keyboard-interactive are different methods

`PasswordAuthentication` and `KbdInteractiveAuthentication` are separate SSH
authentication methods, and this role turns both on together for the accounts in
`ssh_ca_password_auth_users`. That is deliberate.

An interactive `ssh` client will happily use either, so a human cannot tell them
apart. Automated clients often cannot: a client configured only for `password`
has no usable method when the server offers only `keyboard-interactive`, and
reports `Auth cancel`. Enabling just one of the two is a common way to break a
backup or file transfer while leaving human logins working perfectly.

With token-derived principals enabled in the `step_ca` SSH certificate
template, an Entra-authenticated user receives a principal such as
`alice@princeton.edu`. Map that principal to the local Unix account that user
may access. If `groups` is omitted, a newly created account receives the OS
admin group (`sudo`/`wheel`) and `ssh_ca_operator_group`; set `groups: []` for
an unprivileged account.

Set `ssh_ca_allowed_users` when the host image has an `AllowUsers` restriction
such as `AllowUsers pulsys`. The role adds the complete permitted account list
to its sshd drop-in so certificate-backed accounts are not blocked.

## Example play

```yaml
- hosts: ssh_ca_clients
  roles:
    - role: ssh_ca_trust
```

Works on Ubuntu and Rocky; the admin group resolves per-OS (`sudo` on Debian,
`wheel` on RedHat) plus `ssh_ca_operator_group`.

## Testing

```sh
molecule test
```

The default scenario installs the trust config on Ubuntu and checks
idempotence plus the effective `sshd -T` output.

### Notes

Once role is complete user will need to run the following steps.

  1. Initialize your step with the following:

      ```sh
      step ca bootstrap --ca-url https://step-ca.lib.princeton.edu:8443 --fingerprint (contents in group_vars/step_ca/vault.yml)
      ```

  2. login into the server with `step ssh login netid@lib-pxserv01a.princeton.edu`
  3. login into the server with `ssh -o PreferredAuthentications=publickey -o PasswordAuthentication=no netid@lib-pxserv01a.princeton.edu`
