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
5. Validates `sshd -t` **before** restarting (handler ordering guarantees a
   bad config never triggers a restart).
6. Warns if `AllowUsers`/`AllowGroups` could silently block cert logins — this
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
```

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
