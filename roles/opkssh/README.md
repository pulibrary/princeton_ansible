# Ansible Role: opkssh

This role installs and configures OpenPubKey SSH (opkssh) on Linux systems.

## Requirements

- Ansible 2.9 or higher
- Root access on target systems
- Supported OS: Debian/Ubuntu, RHEL/CentOS/Fedora

## Role Variables

Available variables are listed below, along with default values (see `defaults/main.yml`):

```yaml
# User and group for AuthorizedKeysCommand
opkssh_auth_cmd_user: opksshuser
opkssh_auth_cmd_group: opksshuser

# Installation settings
opkssh_install_dir: /usr/local/bin
opkssh_binary_name: opkssh
opkssh_github_repo: openpubkey/opkssh
opkssh_install_version: latest

# Feature flags
opkssh_home_policy: false
opkssh_restart_ssh: true
opkssh_overwrite_active_config: false

# OpenID Providers
opkssh_providers:
  - url: "https://accounts.google.com"
    client_id: "206584157355-7cbe4s640tvm7naoludob4ut1emii7sf.apps.googleusercontent.com"
    ttl: "24h"
  # ... more providers
```

## Dependencies

None.

## Example Playbook

Basic installation:

```yaml
- hosts: servers
  become: yes
  roles:
    - opkssh
```

Installation with custom settings:

```yaml
- hosts: servers
  become: yes
  roles:
    - role: opkssh
      vars:
        opkssh_home_policy: false
        opkssh_install_version: "v1.2.3"
        opkssh_providers:
          - url: "https://accounts.google.com"
            client_id: "your-client-id"
            ttl: "48h"
```

Installation from local file:

```yaml
- hosts: servers
  become: yes
  roles:
    - role: opkssh
      vars:
        opkssh_local_install_file: "/tmp/opkssh-binary"
```

## Advanced Usage

### Disabling Home Policy

To simplify the installation (no sudo configuration):

```yaml
opkssh_home_policy: false
```

### Custom Provider Configuration

You can override the default OpenID providers:

```yaml
opkssh_providers:
  - url: "https://your-idp.example.com"
    client_id: "your-client-id"
    ttl: "12h"
```

### Overwriting Existing Configuration

If you have conflicts with existing SSH configurations. Isn't a new VM a better option :wink: ?

```yaml
opkssh_overwrite_active_config: true
```

Created based on the opkssh installation script from https://github.com/openpubkey/opkssh
