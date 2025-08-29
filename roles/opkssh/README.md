# Ansible Role: opkssh

Installs and configures **OpenPubKey SSH (opkssh)** on Linux in an idempotent, version-pinned way.

---

## Supported

- **OS**: Debian/Ubuntu, RHEL/CentOS/Fedora
- **Arch** (via `opkssh_arch_mapping`): `amd64`/`x86_64`, `arm64`/`aarch64`

## Requirements

- Ansible 2.12+ recommended
- Root privileges on target hosts

---

## How it works

- **Binary** is downloaded to `/tmp` and copied to `{{ opkssh_install_dir }}/{{ opkssh_binary_name }}`.
- We pin the value of `opkssh_install_version` (e.g. `v0.8.0`) so the role compares installed version (or checksum if provided) and replaces only when different.
- **Providers file** `/etc/opk/providers` is created **only** if missing or empty (your manual edits are preserved).
- Drops an sshd **drop-in**: `/etc/ssh/sshd_config.d/{{ opkssh_sshd_config_priority }}-opk-ssh.conf`.
- **SELinux** (if enabled) restores context and loads a tiny module allowing `AuthorizedKeysCommand`.

---

## Key variables

```yaml
# Auth command user/group
# opkssh_auth_cmd_user: the only user that can run whatever command 
# opkssh_auth_cmd_group: the group for the opkssh_auth_cmd_user

# Arch mapping (ansible_architecture -> release suffix)
opkssh_arch_mapping:
  x86_64: amd64
  amd64: amd64
  aarch64: arm64
  arm64: arm64

# Install
opkssh_install_dir: /usr/local/bin
opkssh_binary_name: opkssh
opkssh_github_repo: openpubkey/opkssh
opkssh_install_version: "v0.8.0"   # "latest" or a tag like "v0.8.0"
opkssh_binary_checksum: ""          # RECOMMENDED when pinned: "sha256:<hex>"

# Manage sshd
opkssh_manage_sshd_config: true
opkssh_overwrite_active_config: false
opkssh_sshd_config_priority: 60
opkssh_restart_ssh: true

# Role config paths & logging
opkssh_config_dir: /etc/opk
opkssh_log_file: /var/log/opkssh.log
opkssh_enable_logging: true         # Writes a single line only when the binary actually changes

# Providers (written only if /etc/opk/providers is missing/empty)
# These are the generic values
opkssh_providers:
  - url: "https://accounts.google.com"
    client_id: "206584157355-7cbe4s640tvm7naoludob4ut1emii7sf.apps.googleusercontent.com"
    ttl: "24h"
  - url: "https://login.microsoftonline.com/9188040d-6c67-4c5b-b112-36a304b66dad/v2.0"
    client_id: "096ce0a3-5e72-4da8-9c86-12924b294a01"
    ttl: "24h"
  - url: "https://gitlab.com"
    client_id: "8d8b7024572c7fd501f64374dec6bba37096783dfcd792b3988104be08cb6923"
    ttl: "24h"
  - url: "https://issuer.hello.coop"
    client_id: "app_xejobTKEsDNSRd5vofKB2iay_2rN"
    ttl: "24h"
```

### Example playbooks
Basic installation (pinned version, recommended to allow upgrade)

```yaml
- hosts: servers
  become: true
  roles:
    - role: opkssh
      vars:
        opkssh_install_version: "v0.8.0"
        opkssh_binary_checksum: "sha256:<paste-digest-here>"
```
