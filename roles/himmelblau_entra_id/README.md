# Himmelblau_entra_id

Install and wire up [Himmelblau](https://himmelblau-idm.org/)
 for SSH/PAM + NSS login against Microsoft Entra ID on Ubuntu

This role:

* Adds the Himmelblau package repo and installs the daemon, PAM, and NSS bits

* Writes `/etc/himmelblau/himmelblau.conf` from a template

* Hardens and fixes the systemd unit with a drop-in (ensures `Type=notify`,
  correct Directory settings, coherent `UMask`, and a fixed socket path)

* Updates `nsswitch.conf` to include the `himmelblau` source

* Replaces Ubuntu's common-* PAM stacks with a strict, deterministic
  configuration using `dpkg-divert`

* Manages an SSH `AllowUsers/AllowGroups` include in `sshd_config.d/`

* Enables Entra ID logins through remote desktop (XRDP) on desktop hosts

* Restarts services safely and waits for the daemon socket to be ready

> Be aware that this role changes system authentication, so you could end up
> with a brick

## Supported platforms

* Ubuntu 22.04/24.04 (tested)

The role asserts that `ansible_os_family` is `Debian` and fails fast on
anything else.

## Requirements

* Ansible 2.14+ (or AAP equivalent)

* Collection: `community.general` (for `dpkg_divert`)

* Network egress to `packages.himmelblau-idm.org` and Microsoft login endpoints

* An Entra ID app registration (client/app ID) that's allowed for your tenant

* SSHD must allow keyboard-interactive (the role comments out any
  `KbdInteractiveAuthentication no`)

### What the role changes

* `/etc/apt/sources.list.d/himmelblau.list`

* `/usr/share/keyrings/himmelblau.gpg`

* `/etc/himmelblau/himmelblau.conf`

* `/etc/systemd/system/himmelblaud.service.d/10-dirs.conf`:

  * `Type=notify`

  * `RuntimeDirectory=himmelblaud` (0750)

  * `StateDirectory=himmelblaud` (0750)

  * `CacheDirectory=himmelblaud` (0750)

  * `UMask=0027`

  * `Environment=HIMMELBLAU_SOCKET=/var/run/himmelblaud/socket`

* `/etc/nsswitch.conf` (ensures `passwd`: and `group`: lines include
  `himmelblau`)

* Strict PAM via `dpkg-divert`:

  * `/etc/pam.d/common-auth`

  * `/etc/pam.d/common-account`

  * `/etc/pam.d/common-session`

  * `/etc/pam.d/common-password`

  * The common-auth line includes:

    ```perl
    pam_himmelblau.so ignore_unknown_user mfa_poll_prompt \
      socket=/var/run/himmelblaud/socket connect_timeout_ms=3000 retries=2
    ```

* `/etc/pam.d/xrdp-sesman` (only when XRDP is installed)

* `/etc/ssh/sshd_config.d/99-allow-users-global.conf`

* Starts and enables `himmelblaud`, then waits for
  `/var/run/himmelblaud/socket`

## How local accounts keep working

`common-auth` routes accounts that exist in `/etc/passwd` through `pam_unix`
and everybody else through `pam_himmelblau`:

```pam
auth required                             pam_env.so
auth [default=1 ignore=ignore success=ok] pam_localuser.so
auth [success=2 default=ignore]           pam_unix.so nullok try_first_pass
auth [success=1 default=ignore]           pam_himmelblau.so ignore_unknown_user
auth requisite                            pam_deny.so
auth required                             pam_permit.so
auth optional                             pam_cap.so
```

This matters well beyond SSH: `pulsys`, `sudo`, the local console, and the
remote desktop greeter all authenticate through the same stack.

`common-account` marks a Himmelblau denial as terminal with `auth_err=die`, so
a `pam_allow_groups` rejection cannot be laundered into a success by a later
module.

`common-session` runs `pam_mkhomedir` before `pam_systemd` so a home directory
exists before a graphical session tries to start in it.

## Remote desktop (XRDP) logins

An Xubuntu desktop VM built with `roles/xrdp` needs three things before an
Entra ID user can sign in over RDP, and this role handles all three:

1. **XRDP's PAM service must see Himmelblau.** XRDP authenticates through
   `/etc/pam.d/xrdp-sesman`, which the role rewrites so it includes the
   managed `common-*` stacks.

2. **XRDP must not be forced down the MFA device-code path.** Himmelblau ships
   `xrdp` and `vnc` in `password_only_remote_services_deny_list`, which means
   those services always require MFA. The XRDP login window can only carry a
   single password field, so the device-code conversation can never be
   completed and the login simply fails. The role's default deny list omits
   `xrdp` and `vnc`, and sets `allow_console_password_only = true`. Entra ID
   Conditional Access still triggers MFA where policy demands it.

3. **The session must be able to start.** A home directory is created by
   `pam_mkhomedir`, `systemd-logind` is running so the user gets an
   `XDG_RUNTIME_DIR`, and Entra ID users are added to the local `audio`,
   `video`, `plugdev`, and `netdev` groups that a desktop session expects.

Remote desktop support is enabled by default but is a no-op on hosts where
XRDP is not installed, so servers are unaffected. Apply `roles/xrdp` before
(or alongside) this role on desktop VMs.

### Why himmelblau-qr-greeter is not installed

`himmelblau-qr-greeter` renders the MFA device code as a QR code on the login
screen, but it is a GNOME Shell extension and declares
`Depends: gnome-shell`. On an XFCE host running LightDM, apt satisfies that by
installing GNOME Shell and gdm3, which takes over as the default display
manager and leaves the Xubuntu desktop unreachable. It is therefore left out of
`himmelblau_packages_deb`, and Recommends are disabled so nothing else can pull
a desktop environment in sideways.

As a backstop, the role runs `apt-get install --simulate` before installing
anything and fails if the resulting plan contains any of
`himmelblau_forbidden_packages` (gdm3, gnome-shell, gnome-session,
ubuntu-desktop). Set `himmelblau_guard_desktop_packages: false` to override.

## Break-glass access

This role rewrites the PAM stacks and inserts `himmelblaud` into the NSS chain.
Both sit on the critical path for logging in, so a mistake in either, or a
daemon that stops answering, makes the host unreachable and forces console
access or a rebuild.

Two independent problems can lock you out, and the role now guards both.

### The SSH allowlist must include the account Ansible uses

`allow_users` lists Entra ID netids. The playbook connects as `pulsys`, which is
**not** in that list, so writing `99-allow-users-global.conf` denies the
automation account on the next sshd restart. `allow_users_always` (default
`[pulsys]`) is merged into every generated `AllowUsers` line, and the role
asserts that the connecting account is covered before writing the file. `root`
is deliberately not in that list, so root SSH stays disabled.

### A second sshd that does not use PAM

`himmelblau_breakglass_enable` (default `true`) stands up `ssh-breakglass.service`
on port `2202` before any PAM or NSS change is made:

* `UsePAM no` — sshd has no option to select a PAM service name, so a
  break-glass instance that used PAM would read the very `common-auth` stack
  this role rewrites and fail in exactly the situation it exists to rescue.
* Public key authentication only. The role refuses to enable the instance
  unless a break-glass account has a populated `~/.ssh/authorized_keys`, since
  a port nobody can log in through is worse than none.
* No systemd dependency on `ssh.service` or `himmelblaud.service`, plus
  `Restart=always`, so it survives their failure.
* Account lookup still uses NSS, but `nsswitch.conf` lists `files` before
  `himmelblau`, so local accounts resolve from `/etc/passwd` without waiting on
  the daemon.

Verify it from your workstation **before** trusting it:

```bash
ssh -p 2202 pulsys@sandbox-bitcur1.princeton.edu
```

A campus firewall may block the port, in which case console access remains the
fallback. Set `himmelblau_breakglass_enable: false` once the rollout is stable.

### Himmelblau's own offline breakglass

Separate feature, and not a lockout escape for local accounts: it lets **Entra
ID MFA users** sign in with a cached password verifier while Entra ID is
unreachable. Off by default; verifiers are only cached after a successful online
sign-in, so it must be enabled before an outage to be useful, and it weakens MFA
if the device is stolen.

```yaml
himmelblau_offline_breakglass_enabled: true
himmelblau_offline_breakglass_ttl: "2h"
```

## Ordering: configuration before packages

`nss-himmelblau`'s postinst adds `himmelblau` to the `passwd`, `group`,
`shadow`, and `initgroups` lines of `/etc/nsswitch.conf`. From that point every
name lookup on the host is routed through `nss_himmelblau`, which talks to
`himmelblaud`. If the daemon has no `domains` configured it cannot answer, so
later postinsts that resolve a user, and dpkg itself, block on a daemon that is
waiting for configuration dpkg has not yet allowed to be written. The result is
an install that hangs indefinitely.

The role therefore writes `/etc/himmelblau/himmelblau.conf` and the systemd
drop-in **before** installing any package, and verifies afterwards that
`getent passwd root` still returns within 15 seconds rather than letting every
subsequent task inherit the same hang.

## Recovering from an interrupted run

`himmelblau-sshd-config` installs `/etc/ssh/sshd_config.d/30-himmelblau.conf`
and its postinst then runs `systemctl restart ssh` **directly**, so
`policy-rc.d` cannot suppress it. That stop tears down the SSH session Ansible
is running through, which kills apt/dpkg mid-postinst so the matching start
never happens. Because Ubuntu's `ssh.service` declares
`RuntimeDirectory=sshd`, systemd deletes `/run/sshd` on stop, and sshd cannot
start without it. The host then answers with `Connection refused` (nothing
listening) rather than timing out.

The role now handles this in two layers:

* **Prevention.** Before any package is installed, a drop-in sets
  `RuntimeDirectoryPreserve=yes` and `Restart=always` on `ssh.service`, and
  `/run/sshd` is created plus registered in `/etc/tmpfiles.d`. A postinst
  restart can no longer destroy the privilege separation directory, and sshd
  comes back on its own if it dies.

* **Containment.** The package install runs detached (`async` with `poll: 0`)
  so a dropped connection cannot abort dpkg. The role then waits for the
  connection to return, collects the result, runs `dpkg --configure --pending`,
  and makes sure `ssh` is started again.

If you are recovering a host that was hit by this before the fix, from the VM
console:

```bash
sudo mkdir -p /run/sshd && sudo chmod 0755 /run/sshd
sudo dpkg --configure -a          # finish the interrupted install
sudo sshd -t                      # must print nothing
sudo systemctl start ssh
```

The role also refuses to rewrite the PAM stacks unless `pam_himmelblau.so`,
`pam_localuser.so`, and `pam_mkhomedir.so` are all present, so a
half-installed host cannot get a PAM configuration it is unable to satisfy.

## Role Variables

Selected variables from `defaults/main.yml`:

| Variable | Default | Purpose |
| --- | --- | --- |
| `himmelblau_domain` | `princeton.edu` | Entra ID domain |
| `himmelblau_tenant_id` | Princeton tenant GUID | Entra ID tenant |
| `himmelblau_local_groups` | `[users]` | Local groups every Entra user joins |
| `himmelblau_sudo_groups` | `[]` | Entra group Object IDs granted local sudo |
| `himmelblau_local_sudo_group` | `sudo` | Local group used for `himmelblau_sudo_groups` |
| `himmelblau_cn_name_mapping` | `true` | Allow `netid` instead of full UPN |
| `himmelblau_allow_console_password_only` | `true` | Password-only console auth |
| `himmelblau_password_only_remote_services_deny_list` | ssh, telnet, ftp, rsh, rlogin, rexec, cockpit, mosh | Services that must always do MFA |
| `himmelblau_mfa_poll_prompt_services` | `[ssh, cockpit, xrdp]` | Services needing an MFA poll prompt flush |
| `himmelblau_mfa_method` | `""` (user's own setting) | Force one MFA method, e.g. `PhoneAppOTP` |
| `himmelblau_enable_hello` | `true` | Windows Hello PIN enrolment and sign-in |
| `himmelblau_allow_remote_hello` | `false` | Accept PIN alone for remote services (single factor) |
| `himmelblau_enable_hello_totp` | `true` | Require a local TOTP alongside the PIN |
| `himmelblau_remote_desktop_enable` | `true` | Configure XRDP logins when XRDP is present |
| `himmelblau_remote_desktop_pam_services` | `[xrdp-sesman]` | PAM services rewritten for XRDP |
| `himmelblau_remote_desktop_local_groups` | `[audio, video, plugdev, netdev]` | Extra groups for desktop sessions |
| `himmelblau_install_recommends` | `false` | Let apt install Recommends |
| `himmelblau_guard_desktop_packages` | `true` | Abort if apt would install a desktop/display manager |
| `himmelblau_forbidden_packages` | gdm3, gnome-shell, gnome-session, ubuntu-desktop | Packages that must never be pulled in |
| `himmelblau_apt_async_timeout` | `1800` | Seconds allowed for the detached package install |
| `allow_users` | Princeton netids | SSH `AllowUsers` allowlist |
| `allow_users_always` | `[pulsys]` | Accounts always kept in `AllowUsers` |
| `himmelblau_breakglass_enable` | `true` | Stand up the no-PAM break-glass sshd |
| `himmelblau_breakglass_port` | `2202` | Port for the break-glass instance |
| `himmelblau_breakglass_users` | `[pulsys]` | Accounts allowed on the break-glass port |
| `himmelblau_offline_breakglass_enabled` | `false` | Cached-password sign-in for MFA users during an outage |
| `himmelblau_ssh_service` | `ssh` | SSH unit name to bounce |

## Inventory & vars example

```ini
[sandboxes]
sandbox-fkayiwa1.lib.princeton.edu
```

```yaml
# group_vars/himmelblau/common.yml
himmelblau_domain: "princeton.edu"
himmelblau_tenant_id: "Entra-TENANT-GUID"
himmelblau_domain_app_id: "APP-REGISTRATION-CLIENT-ID"
allow_users:
  - ac2754
  - ar1789
  - fkayiwa
  - gpmenos
  - jkazmier
  - vk4273
  ```

```yaml
# playbooks/himmelblau_entra_id.yml
- name: install himmelblau on {{ inventory_hostname }}
  hosts: sandboxes
  become: true
  vars_files:
    - ../group_vars/himmelblau/common.yml
    - ../group_vars/himmelblau/vault.yml
  roles:
    - role: himmelblau_entra_id
  post_tasks:
    - name: tell everyone on slack you ran an ansible playbook
      community.general.slack:
        token: "{{ vault_pul_slack_token }}"
        msg: "Ansible ran `{{ ansible_play_name }}` on {{ inventory_hostname }}"
        channel: "{{ slack_alerts_channel }}"
```

Xubuntu desktop VM that should accept remote desktop logins:

```yaml
- name: build an Entra ID enabled Xubuntu desktop
  hosts: desktops
  become: true
  vars_files:
    - ../group_vars/himmelblau/common.yml
    - ../group_vars/himmelblau/vault.yml
  roles:
    - role: xrdp
    - role: himmelblau_entra_id
```

`playbooks/desktop_entra_id.yml` does exactly this. Use it rather than
`playbooks/bitcurator_setup.yml` when the point is per-user Entra ID sign-in:
the bitcurator role also creates a local `bcadmin` account with a shared
password, which is what Entra ID authentication is meant to replace.

Role order matters. This role skips its remote desktop work when XRDP is not
installed, so `xrdp` has to be applied first. Running the himmelblau playbook on
its own against a host with no XRDP logs "XRDP is not installed" and moves on,
which is easy to miss.

## Joining the device to Entra ID

There is no enrollment command. `himmelblaud` is only the daemon and takes no
tenant argument; the device joins Entra ID automatically on the first successful
sign-in. To trigger and watch that:

```bash
sudo aad-tool auth-test -D <netid>@princeton.edu
sudo aad-tool status
```

`auth-test` exercises the himmelblaud resolver directly, so it isolates cloud
authentication from PAM configuration. Add `--force-reauth` to bypass a cached
Hello key.

### Why remote desktop shows a blank screen during MFA

The symptom is a blank remote desktop screen with no prompt, while the user's
phone receives an Authenticator request they cannot complete.

Himmelblau sends the MFA device-code message as a PAM informational message
(`PAM_TEXT_INFO`). For every PAM service except `gdm-password` and
`broker-interactive` it also renders the verification URL as unicode QR art and
appends it to that message. The remote desktop login window cannot draw a
multi-line unicode block, so the entire message is lost. The upstream code
already skips the QR for GDM, and for pinentry because it "panics on long Assuan
payloads"; the remote desktop login window has the same limitation but is not
excluded.

The `mfa_poll_prompt` flush does not help here. It is active for remote desktop
already, since the service name `xrdp-sesman` matches the `xrdp` entry in
`mfa_poll_prompt_services` by substring, and the message still cannot be
rendered.

The message is not lost, though: xrdp writes PAM conversation text to
`/var/log/xrdp-sesman.log`, prefixed `PAM:`. The number is therefore recoverable
while a login is in progress, which is useful when diagnosing a stuck sign-in:

```bash
sudo tail -f /var/log/xrdp-sesman.log
```

That is a debugging aid, not a workflow. Nobody should have to read a server log
to sign in.

So MFA cannot practically be completed at the remote desktop login window. The
role instead configures a Hello PIN plus a local one-time code, which replaces
that exchange with two ordinary prompts:

```yaml
himmelblau_enable_hello: true
himmelblau_enable_hello_totp: true
himmelblau_allow_remote_hello: false
```

Sandboxes are configured the same as production here. The weaker alternative,
`allow_remote_hello: true`, accepts the PIN by itself for remote services and so
reduces remote sign-in to a single factor: someone holding the machine with no
route to Entra ID needs only the PIN. It is left off rather than relaxed for
convenience on test hosts.

The one-time code is enrolled and checked on the host itself, independently of
Entra ID, so it also keeps working during an Entra outage.

### Enrolling

Enrol from a terminal, where prompts render correctly. An administrator can do
this with the user present:

```bash
sudo aad-tool auth-test -D <netid>@princeton.edu
```

That prompts for the user's Entra ID password, runs multi-factor authentication
(including the "enter the number NN" step, which displays correctly in a
terminal), then has them set a PIN and enrol a one-time code.

Users who already have a shell on the host can enrol themselves with no
administrator rights, because `pam_himmelblau` implements the PAM
password-change phase (`sm_chauthtok`) and the managed `common-password` stack
puts it ahead of `pam_unix`:

```bash
ssh <netid>@sandbox-bitcur1.princeton.edu
passwd
```

It prints "This command changes your local Hello PIN, NOT your Entra Id
password" so users are not left guessing.

Enrolment must not be attempted over remote desktop. One-time code enrolment
displays the secret as unicode QR art, exactly what the remote desktop login
window cannot draw. Once enrolled, remote desktop sees only plain prompts.

### Rebuilding a host destroys every PIN on it

PIN and one-time-code material is stored on the machine, not in Entra ID:

* `/var/lib/himmelblaud` (or `/var/lib/private/himmelblaud`) holds the sealed
  key material and the HSM pin
* `/var/cache/himmelblaud/himmelblau.cache.db` holds device state and cached
  authentication data
* `hsm_type` defaults to `tpm_bound_soft_if_possible`, so the parent key is
  bound to the machine's TPM where one exists

So wiping a VM invalidates every enrolled PIN on it, and every user has to enrol
again over SSH. Nothing is recoverable from Entra ID, by design: the PIN is a
device credential, which is what makes it a second factor rather than a password.

The Entra ID **device object** is not removed by wiping the machine, and each
rebuild registers a new one. Repeatedly rebuilding a host therefore leaves a
growing pile of stale device records named after it. `aad-tool` has no command to
leave or unregister a device, so stale objects have to be deleted in the Entra
admin centre. Worth checking during a rollout that involves frequent rebuilds,
since Entra enforces a per-user device limit.

For a host that is rebuilt often, it is less painful to snapshot after enrolment
than to re-enrol each time.

### Do users need sudo to enrol?

No, though the question is reasonable: the administrator-driven path above does
require root, because the himmelblaud socket is root-owned (mode 0750, from this
role's systemd drop-in). So `aad-tool` is not something an unprivileged user can
run.

Self-service enrolment avoids it entirely. `passwd` is run by the user as
themselves and needs no special rights.

Do not grant `NOPASSWD` sudo to Entra ID users to make enrolment work. It would
hand every desktop user unauthenticated root, which is a far larger exposure
than anything else discussed here, to solve a problem that has a
no-privilege answer.

If Entra ID users genuinely need sudo on a host, grant it by group membership
rather than by relaxing authentication:

```yaml
# Object IDs, not group names: Entra names are not unique
himmelblau_sudo_groups:
  - <entra-group-object-id>
himmelblau_local_sudo_group: sudo
```

Those users then authenticate to sudo with their Hello PIN, which works fine in
a terminal. The `no_hello_pin` module option can force a full MFA round trip for
sudo specifically if you want stronger confirmation for privilege escalation.

### Forcing a particular MFA method

`himmelblau_mfa_method` requests one specific method rather than whatever the
user has configured in Entra ID. `PhoneAppOTP` turns MFA into a code the user
reads from their phone and types in, which needs nothing displayed back to them:

```yaml
himmelblau_mfa_method: PhoneAppOTP
```

This is useful for SSH and console logins. It does not rescue the remote desktop
login window on its own, because the polling message is still sent the same way.
Leave it empty to use each user's own Entra ID setting.

## Verifying

`pamtester` is not installed by default on these hosts. The role installs it
itself when `himmelblau_verify_pam` is true (the default) and, **before
restarting SSH**, checks that local accounts still pass PAM account management.
Only the account phase is tested: it needs no password, so it cannot block
waiting for input, and it is where this role's changes are most likely to bite.
If the check fails the play stops with SSH still running, so existing sessions
keep working and the `.distrib` copies can be restored.

The role then confirms a brand new connection can be established after the
restart, rather than assuming it.

To check by hand on the endpoint:

```bash
sudo apt -y install pamtester

# Account phase: no password needed, safe to run over SSH
sudo pamtester -v sshd pulsys acct_mgmt
sudo pamtester -v sudo  pulsys acct_mgmt

# Full authentication: prompts for a password, so run it from a console
sudo pamtester -v sshd <netid>@princeton.edu authenticate
sudo pamtester -v xrdp-sesman <netid>@princeton.edu authenticate

# Name lookups must return immediately, not hang on himmelblaud
getent passwd root
getent passwd <netid>@princeton.edu

# Daemon health
sudo systemctl status himmelblaud
sudo journalctl -u himmelblaud -n 120 --no-pager
sudo ls -l /run/himmelblaud
```

The single most reliable check costs nothing: with your current session still
open, start a **new** SSH session from your workstation. If that succeeds,
authentication is intact.

From remote (your workstation)

```bash
ssh -o PreferredAuthentications=keyboard-interactive \
    -o KbdInteractiveDevices=pam \
    -o PubkeyAuthentication=no \
    -l <netid> sandbox-rl36671.lib.princeton.edu
```

For remote desktop, connect any RDP client to port 3389 and sign in with your
netid and Entra ID password. Session startup is logged to
`/tmp/xrdp-startwm-<user>-<display>.log` and sesman activity lands in
`/var/log/xrdp-sesman.log`.
