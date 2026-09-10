Authentication flow
===================

How a login on an SFTP host is authenticated, and which role owns which part.

The transfer accounts are **directory accounts**. This role does not create them
and does not store their passwords; it makes sure sshd offers them a method they
can actually use, and that the drop directories belong to them.

Who authenticates how
---------------------

| Login | Method | Verified by |
| --- | --- | --- |
| `almasftp`, `lib-aspacesftp` | Password | Active Directory, through PAM |
| `pulsys`, `deploy` | SSH public key | local `authorized_keys` |

For how Active Directory resolves and authenticates the two transfer accounts,
see [the sssd_ldap authentication flow](../sssd_ldap/AUTH_FLOW.md). This document
covers only the SFTP host itself.

What sshd is asked to allow
---------------------------

Alma and ArchivesSpace can present neither a key nor a certificate, so these two
accounts need password authentication even where the host image switches it off.
The role writes one drop-in that does exactly that, scoped to those accounts.

```mermaid
---
title: "Which method sshd offers, per account"
---
flowchart TD
  L["Connection as some user"] --> A{"Named in any<br/>AllowUsers line?"}
  A -->|no| DENY(["Refused, whatever<br/>else permits it"])
  A -->|yes| M{"Named in the<br/>Match User block?"}
  M -->|"yes: almasftp,<br/>lib-aspacesftp"| PW["Password and<br/>keyboard-interactive<br/>both offered"]
  M -->|no| KEY["Whatever the host<br/>already allowed,<br/>normally keys only"]
  PW --> PAM["PAM asks Active Directory"]
  KEY --> AK["sshd checks authorized_keys"]
```

Two details in that diagram cause most real failures.

**`AllowUsers` is a veto.** It accumulates across every `sshd_config.d` file
rather than the first one winning, but if any `AllowUsers` exists anywhere, an
account named in none of them is refused however else it is permitted. The
transfer accounts are therefore listed explicitly, alongside `pulsys` and the
deploy user so the role can never lock out administrative access.

**Password and keyboard-interactive are separate methods.** An interactive `ssh`
client quietly uses either, so a successful human login proves nothing about an
automated one. Alma drives transfers with a Java library that may negotiate only
one of the two, and Rocky's stock `50-redhat.conf` ships
`ChallengeResponseAuthentication no`, which disables keyboard-interactive
host-wide. Both are enabled for these accounts so neither choice fails.

How the roles combine
---------------------

```mermaid
---
title: "Roles applied per environment"
---
flowchart TD
  subgraph sandbox["Sandbox: sandbox-sftp1, Ubuntu"]
    C1["sssd_ldap<br/>Active Directory over LDAPS"] --> D1["lib_sftp<br/>drop directories, sshd methods"]
    C3["deploy_user"] --> D1
  end
  subgraph prod["Staging and production, Rocky"]
    A1["ad_join<br/>realm join, Kerberos"] --> B1["lib_sftp<br/>drop directories, sshd methods"]
    A3["deploy_user"] --> B1
  end
```

`lib_sftp` depends only on `deploy_user`. The identity provider is chosen in the
playbook, because it is the one piece that differs by operating system:
`playbooks/lib_sftp.yml` adds `ad_join`, and `playbooks/sandbox_sftp.yml` adds
`sssd_ldap`. Both reach the same Active Directory.

Ordering matters. The identity role has to run first, or NSS cannot resolve the
transfer accounts and the drop directories cannot be chowned to them. The role
asserts this up front so the failure names the cause instead of surfacing later
as an ownership error.

Diagnosing a failure
--------------------

```sh
ansible-playbook playbooks/utils/sftp_auth_debug.yml -e probe_hosts=libsftp_staging
```

The single most useful command is to ask sshd what a real login would get,
because it resolves every drop-in and `Match` block:

```sh
sudo sshd -T -C user=almasftp,host=alma.exlibrisgroup.com,addr=1.2.3.4 \
  | grep -iE 'passwordauth|kbdinteractive|allowusers'
```

Then force each method separately, since an automated client may only use one:

```sh
ssh -o PreferredAuthentications=password almasftp@thehost
ssh -o PreferredAuthentications=keyboard-interactive almasftp@thehost
```

Read the client error carefully. The two look alike and mean different things:

| Client says | Meaning |
| --- | --- |
| `Auth fail` | the password was wrong |
| `Auth cancel` (JSch) | no acceptable method was offered, **or** the password was refused and the client had nothing left to try |
| `Permission denied (publickey,...)` | the listed methods are all the server offered |

Neither indicates a firewall problem: the connection already reached the
authentication stage. A wrong password appears in the sssd journal as
`Preauthentication failed`; compare its timestamp against `lastb` and the
client's source address. That is what actually broke staging.
