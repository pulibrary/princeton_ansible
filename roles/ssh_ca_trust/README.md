# ssh_ca_trust

Configures an SSH host to accept certificates signed by the `step_ca` SSH
**User** CA. The host never talks to step-ca or Entra — it is a relying party
that trusts a static public key. No secrets are involved, so this role is safe
to apply broadly and is a good candidate to fold into the `common` role once
the SSH-CA pilot graduates.

## What it does

1. Installs `openssh-server`.
2. Writes the User CA public key to `/etc/ssh/trusted_user_ca_keys.pem`
   (optionally asserting `ssh_ca_user_ca_fingerprint`).
3. Creates local users and their `/etc/ssh/auth_principals/%u` files.
4. Drops `60-ssh-ca-access.conf` into `sshd_config.d`.
5. Optionally re-enables password authentication for named service accounts
   inside a `Match User` block, leaving the host password-less for everyone
   else. The password is checked by the directory through PAM, never by this
   role.
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
  - name: almasftp
    # A directory-backed service account: do not create it locally.
    create_local_user: false

# Accounts allowed to authenticate with a password as well as a certificate.
ssh_ca_password_auth_users:
  - almasftp
```

## Password authentication for service accounts

The host default is `PasswordAuthentication no`. Some service accounts (SFTP
drop-off users, vendor integrations) cannot present a certificate, so list them
in `ssh_ca_password_auth_users`. The role emits a `Match User` block that turns
password and keyboard-interactive authentication back on for just those
accounts, then closes with `Match all` so nothing parsed after the include is
accidentally scoped to the match.

This role never stores or sets a password. The account must come from a
directory that answers PAM, so pair it with `ad_join` (realm-joined Active
Directory) or `sssd_ldap` (Active Directory over LDAPS, no join).
Keyboard-interactive is enabled alongside password because sssd prompts through
PAM.

When the identity source uses UPN-style logins (`almasftp@princeton.edu`),
list every form users actually type, since `Match User` compares the literal
name supplied at login.

Password-only service accounts cannot use `entraid_join`: Himmelblau forces MFA
on every remote session, so the login fails even with the correct password.

## Avoid two roles writing `AllowUsers`

`AllowUsers` **accumulates**: every line in `sshd_config` and in every
`sshd_config.d` drop-in is appended to one list, so two roles each adding a line
both take effect. Verify with
`sshd -T -C user=name,host=h,addr=1.2.3.4 | grep -i allowusers`.

Scalar keywords behave the opposite way. `PasswordAuthentication`,
`KbdInteractiveAuthentication` and friends take the **first** value parsed, and
`Include /etc/ssh/sshd_config.d/*.conf` sits at the top of the file on Debian
and RHEL alike. A drop-in that sorts earlier therefore wins outright, which is
why `60-ssh-ca-access.conf` beats anything set later in `sshd_config`.

Keep access control in one place regardless. When an identity role already
restricts who may authenticate (`simple_allow_users` in sssd, or
`entraid_join_pam_allow_groups`), set `ssh_ca_allowed_users: []` so this role
emits no `AllowUsers` at all.

## Password and keyboard-interactive are different methods

`PasswordAuthentication` and `KbdInteractiveAuthentication` are separate SSH
authentication methods, and this role turns both on together for the accounts in
`ssh_ca_password_auth_users`. That is deliberate.

An interactive `ssh` client will happily use either, so a human cannot tell them
apart. Automated clients often can: a Java client using JSch (which is what Alma
uses) may be configured only for `password`, and if the server offers only
`keyboard-interactive` the client has no usable method and reports
`Auth cancel`. Enabling just one of the two is a common way to break a file
transfer while leaving human logins working perfectly.

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
