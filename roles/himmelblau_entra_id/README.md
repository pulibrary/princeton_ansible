# Himmelblau_entra_id

Install and wire up [Himmelblau](https://himmelblau-idm.org/)
 for SSH/PAM + NSS login against Microsoft Entra ID on Ubuntu

This role:

* Adds the Himmelblau package repo and installs the daemon, PAM, and NSS bits

* Writes `/etc/himmelblau/himmelblau.conf` from a template

* Hardens and fixes the systemd unit with a drop-in (ensures `Type=notify`, correct Directory settings, coherent `UMask`, and a fixed socket path)

* Updates `nsswitch.conf` to include the `himmelblau` source

*Replaces Ubuntu’s common-* PAM stacks with a strict, deterministic configuration using `dpkg-divert`

* Manages an SSH `AllowUsers/AllowGroups` include in `sshd_config.d/`

* Restarts services safely and waits for the daemon socket to be ready

> This changes system authentication.

## Supported platforms

* Ubuntu 22.04/24.04 (tested)

* Rocky Linux 8/9 tasks scaffolded; ensure `tasks/rocky.yml`

## Requirements

* Ansible 2.14+ (or AAP equivalent)

* Collection: `community.general` (for `dpkg_divert`)

* Network egress to `packages.himmelblau-idm.org` and Microsoft login endpoints

* An Entra ID app registration (client/app ID) that’s allowed for your tenant

* SSHD must allow keyboard-interactive (the role comments out any `KbdInteractiveAuthentication no`)

### What the role changes

* `/etc/apt/sources.list.d/himmelblau.list` (Ubuntu) or a YUM repo (Rocky)

* `/usr/share/keyrings/himmelblau.gpg` (Ubuntu)

* `/etc/himmelblau/himmelblau.conf`

* `/etc/systemd/system/himmelblaud.service.d/10-dirs.conf`:

  * `Type=notify`

  * `RuntimeDirectory=himmelblaud` (0750)

  * `StateDirectory=himmelblaud` (0750)

  * `CacheDirectory=himmelblaud` (0750)

  * `UMask=0027`

  * `Environment=HIMMELBLAU_SOCKET=/var/run/himmelblaud/socket`

* `/etc/nsswitch.conf` (ensures `passwd`: and `group`: lines include `himmelblau`)

* Ubuntu only (strict PAM) via `dpkg-divert`:

  * `/etc/pam.d/common-auth`

  * `/etc/pam.d/common-account`

  * `/etc/pam.d/common-session`

  * `/etc/pam.d/common-password`

  * The common-auth line includes:

    ```perl
    pam_himmelblau.so ignore_unknown_user mfa_poll_prompt socket=/var/run/himmelblaud/socket connect_timeout_ms=3000 retries=2
    ```

* `/etc/ssh/sshd_config.d/99-allow-users-global.conf`

* Starts and enables `himmelblaud`, then waits for `/var/run/himmelblaud/socket`
