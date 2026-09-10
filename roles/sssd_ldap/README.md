# sssd_ldap

Resolve and authenticate **Active Directory** accounts over LDAPS using sssd,
without joining the domain.

See [AUTH_FLOW.md](AUTH_FLOW.md) for diagrams of how the SFTP transfer accounts
`almasftp` and `lib-aspacesftp` are resolved and authenticated, and how to read
a failure.

## Why this exists

`ad_join` performs a full realm join and only works on Rocky: it installs
`authselect-compat` and `krb5-workstation`, neither of which exists in the Ubuntu
archive, and it drives `realm join` through `expect`. This role reaches the same
directory with far less machinery.

| | `ad_join` | `sssd_ldap` |
| --- | --- | --- |
| Computer object and keytab | yes | none |
| Kerberos, DNS SRV, clock skew | required | not used |
| `authselect` custom profile | yes, RHEL only | none |
| Runs on Ubuntu | no | yes |

It is **not** an Entra ID client. Entra ID exposes no LDAP interface, so it
cannot be a target for this role, and Himmelblau forces MFA on remote sessions
which rules Entra out for password-only service accounts entirely.

## What it does

1. Installs sssd and the LDAP back end.
2. Writes `/etc/sssd/sssd.conf` with `id_provider = ldap` and
   `ldap_schema = ad`, mode `0600` because it carries the lookup password.
3. Adds `sss` to `passwd`, `group` and `shadow` in `nsswitch.conf`.
4. Enables the `sss` and `mkhomedir` PAM profiles (`pam-auth-update` on Debian,
   `authselect` on RedHat), refusing to overwrite a custom profile another role
   owns.
5. Validates with `sssctl config-check` **before** restarting sssd.
6. Flushes handlers, then confirms every permitted account actually resolves,
   with a specific diagnosis when one does not.

## Variables

```yaml
sssd_ldap_domain: pu.win.princeton.edu
sssd_ldap_search_base: dc=pu,dc=win,dc=princeton,dc=edu
sssd_ldap_uri:
  - ldaps://pdom21tlkp.pu.win.princeton.edu

# Lookup account, from vault. A bare name is qualified with
# sssd_ldap_upn_suffix, because an LDAP simple bind needs a full distinguished
# name or a login name, not the bare name a Kerberos join accepts.
sssd_ldap_bind_dn: "{{ sssd_bind_dn }}"
sssd_ldap_bind_password: "{{ sssd_bind_dn_password }}"

# The login-name suffix the directory publishes, which is NOT necessarily the
# domain name. Here accounts live in pu.win.princeton.edu but log in as
# name@princeton.edu.
sssd_ldap_upn_suffix: princeton.edu

# Only these accounts may log in. Empty allows anyone the directory resolves.
sssd_ldap_allow_users:
  - almasftp
  - lib-aspacesftp
```

`sssd_ldap_allow_users` becomes `simple_allow_users`, so access control lives in
sssd rather than in sshd `AllowUsers`. That matters because `AllowUsers`
accumulates across every `sshd_config.d` drop-in, and splitting the decision
across files makes the effective list hard to reason about.

`sssd_ldap_id_mapping` is `false`, so UIDs come from the directory's `uidNumber`
and `gidNumber` rather than being derived from the SID. This keeps them identical
to the realm-joined hosts, which matters for file ownership on shared storage.
**An account without those attributes will not resolve at all.**

## LDAPS is mandatory

Authentication is an LDAP simple bind, so the user's password crosses the
network. The role refuses to run unless every URI is `ldaps://` and
`sssd_ldap_tls_reqcert` is `demand` or `hard`. If the domain controllers use an
internal CA, point `sssd_ldap_tls_cacert` at it; the default is the system trust
bundle.

## Choosing an identity source

| Login type | Use |
| --- | --- |
| Service account, password, no MFA | this role, or `ad_join` on Rocky |
| Staff shell access | `ssh_ca_trust`, certificates via step-ca |
| Interactive Entra login with MFA | `entraid_join` |

## Verifying

```sh
getent passwd almasftp            # directory lookup works
id almasftp                       # uid and gid come from the directory
sudo sssctl config-check
sudo sssctl domain-status pu.win.princeton.edu
```

An SSH login runs two PAM phases, and checking only the first is a common
mistake:

```sh
sudo sssctl user-checks almasftp -s sshd -a auth   # is the password right?
sudo sssctl user-checks almasftp -s sshd -a acct   # may it log in here?
```

Then prove the real thing, forcing each method separately because an automated
client may only negotiate one of them:

```sh
ssh -o PreferredAuthentications=password almasftp@thehost
ssh -o PreferredAuthentications=keyboard-interactive almasftp@thehost
```
