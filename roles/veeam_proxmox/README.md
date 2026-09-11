# veeam_proxmox

Prepares a Proxmox VE node so Veeam Backup & Replication can manage it as a
non-root service account, instead of handing Veeam the `root` password.

Veeam drives each node over SSH and elevates individual commands with `sudo`,
so three things have to line up before it will even accept the credentials:

| Layer | What Veeam needs | Owner |
| --- | --- | --- |
| SSH | password login for the service account | `ssh_ca_trust` |
| Host | `sudo` granting a fixed command list, **with** a password prompt | this role |
| Proxmox API | the built-in `Administrator` role | this role |

Missing any one of them produces an error that points somewhere else, which is
what makes this integration hard to debug. See [AUTH_FLOW.md](AUTH_FLOW.md) for
what each error message actually means.

## What it does

1. Installs `sudo` and `dmidecode`. Proxmox VE ships neither, and a missing
   `dmidecode` is the most common cause of credential validation failing.
2. Asserts `sudo` is 1.9.10 or newer. Veeam's rules use regular expressions in
   command arguments, which older versions cannot parse.
3. Ensures `/etc/sudoers` really includes `/etc/sudoers.d`. A commented or
   mistyped `@includedir` line silently discards the drop-in below.
4. Creates the service account with `/bin/bash` (Veeam supports no other shell),
   a group of its own, and optionally sets its password.
5. Removes superseded hand-made drop-ins (`veeam_proxmox_superseded_sudoers`)
   and writes the granular sudoers drop-in from Veeam KB4701, validated with
   `visudo` before it is installed.
6. Keeps the account out of every supplementary group, then asks `sudo` whether
   it would run a command with no password prompt and fails if it would.
7. Creates the matching Proxmox user and grants it `Administrator` on `/`.

## Variables

```yaml
veeam_proxmox_user: veeam-service

# Crypt hash, normally from a vault. Leave empty to keep the existing password.
veeam_proxmox_user_password: "{{ vault_veeam_service_password }}"

# Proxmox API side. Set false when the host is not a Proxmox node.
veeam_proxmox_manage_pve_user: true
veeam_proxmox_pve_role: Administrator

# The sudo command list, from Veeam KB4701. Update it when the plug-in is
# upgraded: the list changed between plug-in 12.1.3 and 13.2.0.
veeam_proxmox_sudo_commands: [...]
```

Generate the password hash with:

```sh
ansible localhost -m debug -a "msg={{ 'thepassword' | password_hash('sha512') }}"
```

## Why PASSWD and not NOPASSWD

Every entry is `PASSWD:`, deliberately. Veeam sends the account password with
each `sudo` call and expects to be prompted; if `sudo` never asks, Veeam waits
for a prompt that does not come and reports
`The password request timeout has expired`. `NOPASSWD` therefore breaks the
integration rather than easing it.

This matters here because the Proxmox nodes grant their operators group blanket
`NOPASSWD` sudo. The role therefore declares the account's supplementary groups
rather than appending to them, so an account that was put in that group by hand
is taken back out.

Whether an inherited `NOPASSWD` rule actually wins is decided by parse order:
sudo applies the **last** matching rule, and files in `/etc/sudoers.d` are read
in lexical order. `opsys` sorts before `veeam-service`, so today the explicit
`PASSWD` rule wins and the prompt still happens. Rename either file, or add a
group rule that sorts later, and it silently flips. Reading the rules therefore
tells you very little, so the role asks sudo what it would really do: it tries
the command as the account with `sudo -n` and fails if that succeeds, naming the
groups and rules involved.

## Granular on the host, not in the API

The sudo list is least-privilege, but Proxmox API access is not: Veeam needs the
built-in `Administrator` role to enumerate VMs, read storage, and take and
release locks. Veeam has not made that side granular, so the role grants the
role Veeam documents rather than inventing a narrower one.

The role locates `pveum` by searching `veeam_proxmox_pveum_candidates`, since
packaging has moved it between `sbin` and `bin`. If it finds none it fails rather
than skipping: without API privileges Veeam still cannot back anything up, and
that would surface much later as an unexplained empty inventory. For a host that
is not a Proxmox node yet, set `veeam_proxmox_manage_pve_user: false`.

## The file name decides who wins

sudo reads `/etc/sudoers.d` in lexical order and applies the **last** matching
rule. A leftover file named `veeam-service-bk` is therefore parsed after
`veeam-service` and silently overrides it, which is how one node ended up with
passwordless sudo despite a correct managed file sitting right next to it.

Had that file been named `veeam-service.bk`, sudo would have ignored it entirely,
because it skips names containing a dot. A backup copy either does nothing or
quietly takes over depending on the punctuation used, so the role deletes the
paths listed in `veeam_proxmox_superseded_sudoers` rather than relying on anyone
remembering which is which.

Those paths are listed explicitly rather than matched by wildcard: deleting
sudoers files that a glob happened to catch is not a risk worth taking. If you
find another leftover, add its path there so every node is cleaned rather than
fixing one by hand.

## In the Veeam console

The role cannot configure the backup server. When adding the credentials there:

- enable **Elevate account privileges automatically**
- leave **Add account to the sudoers file** off, or Veeam overwrites this
  drop-in with a blanket rule
- leave **Use "su" if "sudo" fails** off

## Example play

```yaml
- hosts: proxmox_servers_staging
  become: true
  roles:
    - role: ssh_ca_trust
    - role: veeam_proxmox
```

## Testing

```sh
molecule test
```

The scenario runs on Ubuntu 24.04 rather than 22.04 because 22.04 ships sudo
1.9.9, which is too old for these rules. It checks the account, the sudoers
drop-in, the include line, and that `sudo` both permits the command Veeam probes
with and refuses an unrelated one. Proxmox tooling is absent in a container, so
the API tasks are skipped there.

## Reference

- [Veeam KB4701](https://www.veeam.com/kb4701) — granular sudo permissions for
  the Proxmox VE plug-in. The command list is version specific; re-check it
  after a plug-in upgrade.
