# entraid_join

Configure headless Microsoft Entra ID login on Ubuntu and Rocky Linux using Himmelblau.

This role is intended for SSH/PAM/NSS login without a GUI.

## Supported platforms

- Ubuntu 22.04 by default
- Rocky Linux 9 by default

Override repository release variables for other supported releases.

## What this role does

- Installs Himmelblau packages
- Configures `/etc/himmelblau/himmelblau.conf`
- Enables `himmelblaud`
- Configures NSS for `passwd` and `group` lookup through Himmelblau
- Configures PAM for headless MFA
- Configures SSH for PAM and keyboard-interactive authentication
- Comments out `AllowUsers` during the pilot because OpenSSH `AllowUsers` does not work cleanly with Entra UPN-style usernames
- Creates `/etc/krb5.conf.d`

## Example

```yaml
- hosts: entraid_test
  become: true
  roles:
    - role: entraid_join
      vars:
        entraid_join_domain: princeton.edu
        entraid_join_debug: true
  ```

### SSH test

Use the explicit login name form:

```sh
ssh -l 'netid@princeton.edu' sandbox-host.lib.princeton.edu
```

For Microsoft Authenticator number matching:

- Enter the Entra password.
- Open Authenticator.
- Enter the displayed number.
- Approve the sign-in.
- Then press Enter in the SSH session.

#### Post-login checks

```sh
whoami
id
groups
pwd
echo "$HOME"
ls -ld "$HOME"
```

From an existing local session:

```sh
getent passwd fkayiwa
getent passwd '<fkayiwa@princeton.edu>'
id fkayiwa
id netid@princeton.edu
```

### Important notes

Do not use OpenSSH `AllowUsers` for Entra/Himmelblau UPN users.

Use `pam_allow_groups` in `himmelblau.conf` after the pilot is working.

Example:

```yaml
entraid_join_pam_allow_groups:

- "00000000-1111-2222-3333-444444444444"
```

Use Entra group object IDs for production access control.

---

## Example playbook

```yaml
---
- name: Configure headless Entra ID login
  hosts: entraid_linux
  become: true

  roles:
    - role: entraid_join
      vars:
        entraid_join_domain: princeton.edu
        entraid_join_debug: true
        entraid_join_disable_allowusers: true
```

### Validation commands

Run these after the role completes.

#### Ubuntu

```sh
sudo sshd -T | egrep 'usepam|kbdinteractiveauthentication|passwordauthentication|allowusers'
grep -R "pam_himmelblau" /etc/pam.d
grep -E '^(passwd|group):' /etc/nsswitch.conf
sudo aad-tool status
```

Expected SSH output:

```text
usepam yes
passwordauthentication yes
kbdinteractiveauthentication yes
```

No `allowusers` output during the pilot.

#### Rocky

```sh
sudo sshd -T | egrep 'usepam|kbdinteractiveauthentication|passwordauthentication|allowusers|challengeresponseauthentication'
grep -R "pam_himmelblau" /etc/pam.d/system-auth /etc/pam.d/password-auth /etc/pam.d/sshd
grep -E '^(passwd|group):' /etc/nsswitch.conf
sudo aad-tool status
```

Expected SSH output:

```text
usepam yes
passwordauthentication yes
kbdinteractiveauthentication yes
```

No `allowusers` output during the pilot.

#### Test SSH

```sh
ssh -l 'netid@princeton.edu' sandbox-host.lib.princeton.edu
```

For production, the next step is to set:

```yaml
entraid_join_pam_allow_groups:
  - "<entra-group-object-id>"
```

and turn off debug:

```yaml
entraid_join_debug: false
```

```text
```
