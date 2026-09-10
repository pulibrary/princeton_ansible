lib_sftp
========

Configures the permissions and drop directories of the Library SFTP servers,
where Alma and ArchivesSpace deposit and collect files.

Requirements
------------

Ubuntu 24.04 or Rocky 9. The transfer accounts are **directory** accounts, so an
identity provider role must run before this one; see Dependencies.

Role Variables
--------------

```yaml
almasftp_user: almasftp
aspaceftp_user: lib-aspacesftp
```

`lib_sftp_owner_group` (default `pusvc-g`) owns the drop directories. Active
Directory supplies this group (gid 20204) and it is the transfer accounts'
primary group, so the role normally finds it already present.

`lib_sftp_group_members` (default empty) lists **local** accounts to add to that
group. Leave it empty when the transfer accounts come from a directory, because
`usermod` cannot modify an account that is absent from `/etc/passwd`.

The role begins by asserting that `almasftp_user` and `aspaceftp_user` resolve.
Without that check, a missing identity provider surfaces later as a confusing
"chown failed" on the drop directories.

Dependencies
------------

`ssh_ca_trust` and `deploy_user`.

This role deliberately does **not** pull in an identity provider, because it
differs per operating system. Add one in the playbook:

- Staging and production (Rocky) use `ad_join`, a full realm join with Kerberos
  and a machine account. See `playbooks/lib_sftp.yml`.
- The sandbox (Ubuntu) uses `sssd_ldap`, which binds to the same Active
  Directory over LDAPS with no join. `ad_join` cannot run there: it needs
  `authselect-compat` and `krb5-workstation`, which Ubuntu does not package.
  See `playbooks/sandbox_sftp.yml`.

Either way the accounts live in the directory, never in `/etc/passwd`.
`ssh_ca_trust` adds certificate trust for staff logins and turns off password
authentication host-wide, so list the transfer accounts in
`ssh_ca_password_auth_users` to exempt them.

See [AUTH_FLOW.md](AUTH_FLOW.md) for diagrams of how each login is
authenticated, how to diagnose a failure, and the pitfalls to avoid.

Example Playbook
----------------

```yaml
- name: Build the sandbox SFTP host
  hosts: libsftp_sandbox
  become: true
  vars_files:
    - ../group_vars/sftp/vault.yml
    - ../group_vars/sftp/common.yml
    - ../group_vars/sftp/sandbox.yml
  roles:
    - role: sssd_ldap
    - role: lib_sftp
```

Verifying
---------

The only test that matters is whether a transfer account can log in the way its
remote partner does:

```sh
ssh -o PreferredAuthentications=password almasftp@thehost
ssh -o PreferredAuthentications=keyboard-interactive almasftp@thehost
```

Both should succeed. Alma uses the Java JSch library and may negotiate either
one, so enabling only a single method breaks transfers while leaving human
logins working.

When something is wrong:

```sh
ansible-playbook playbooks/utils/sftp_auth_debug.yml -e probe_hosts=libsftp_staging
```

License
-------

MIT
