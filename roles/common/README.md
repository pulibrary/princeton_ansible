# roles/common

## Description

The **common** role bootstraps our Linux servers with a standard baseline of tools, configurations, and services used across our infrastructure. It ensures a consistent environment by installing essential packages, setting up shell/editor configs, implementing a flexible, hierarchical log rotation system for application logs, managing systemd journal log disk usage, and deploying observability tools.

## Features

- **Package Installation**
  - Installs shared packages (`curl`, `git`, `htop`, `jq`, `tmux`, `vim`, etc.) on all hosts.
  - Installs OS-specific packages for Debian/Ubuntu and RHEL families.
- **Shell & Editor Configuration**
  - Deploys a global `tmux` configuration (`/etc/tmux.conf`).
  - Creates `/etc/vim/vimrc.local` for Vim customizations.
- **SSH Key Management**
  - Fetches public keys from GitHub for operations, library, CDH, and EAL teams.
- **Journal Log Management**
  - Configures systemd journal log disk usage limits via `/etc/systemd/journald.conf.d/`.
  - Prevents journal logs from consuming excessive disk space.
  - Automatically restarts `journald` when settings are changed.
- **Log Rotation**
  - Creates a systemd timer override to periodically check log sizes and trigger rotations.
  - Defines **global defaults** (`logrotate_global_defaults`) and **custom rules** (`logrotate_rules`) for `/etc/logrotate.d/`.
- **Observability & Utilities**
  - Installs and configures the [Vector](https://vector.dev/) agent for centralized log forwarding.
  - Installs [dua-cli](https://github.com/Byron/dua-cli/) for fast disk usage reporting.

## Requirements

- Ansible **2.9+**
- Python **3.x** on target hosts
- **systemd** for timer management and journal configuration (Debian/RHEL)

## Role Variables

All defaults can be found in `roles/common/defaults/main.yml`. Override these in your inventory or playbook as needed.

### General Settings

| Variable                  | Default                                  | Description                                       |
| ------------------------- | ---------------------------------------- | ------------------------------------------------- |
| `common_shared_packages`  | `[curl, git, htop, jq, tmux, tree, vim]` | Packages installed on **all** hosts.              |
| `common_ubuntu_packages`  | `[acl, build-essential, python3-pip, …]` | Debian/Ubuntu-specific packages.                  |
| `common_rhel_packages`    | `[@Development tools, libyaml, …]`       | RHEL/CentOS-specific packages.                    |
| `configured_dependencies` | `[]`                                     | Additional packages to install.                   |
| `system_install_dir`      | `/usr/local/bin`                         | Directory to install CLI tools (e.g., `dua-cli`). |

### Journald Configuration

The role manages systemd journal log disk usage to prevent journal logs from consuming excessive space. Configuration is done via `/etc/systemd/journald.conf.d/00-journal-size.conf`.

| Variable                       | Default | Description                                                    |
| ------------------------------ | ------- | -------------------------------------------------------------- |
| `journald_system_max_use`      | `800M`  | Maximum disk space journal logs can use (recommended setting). |
| `journald_system_keep_free`    | *unset* | Ensures specified amount of disk space remains free.           |
| `journald_system_max_file_size`| *unset* | Maximum size of individual journal files.                      |
| `journald_system_max_files`    | *unset* | Maximum number of individual journal files.                    |

**Note:** `SystemMaxUse` is the recommended setting as it provides predictable disk usage. When journal settings are modified, `journald` is automatically restarted to apply the changes.

**Example:** Override for high-volume systems in `group_vars/production/vars.yml`:

```yaml
journald_system_max_use: "2G"
```

To verify journal disk usage on a host:

```bash
sudo journalctl --disk-usage
```

### Logrotate Configuration

| Variable                    | Default                              | Description                                            |
| --------------------------- | ------------------------------------ | ------------------------------------------------------ |
| `logrotate_global_defaults` | See defaults file                    | Base settings for all logrotate configurations.        |
| `logrotate_rules`           | `[ - name: "custom-application" … ]` | List of custom logrotate jobs for `/etc/logrotate.d/`. |

Customize logrotate per service or environment by overriding `logrotate_rules` in `group_vars`.

### Vector Agent Settings

| Variable                      | Default                                      | Description                                      |
| ----------------------------- | -------------------------------------------- | ------------------------------------------------ |
| `vector_url`                  | `https://packages.timber.io/vector`          | Repository URL for Vector installation.          |
| `vector_enable_console_debug` | `true`                                       | Enable console debug logs (for troubleshooting). |
| `vector_api_enabled`          | `true`                                       | Enable Vector's HTTP API endpoint.               |

## Dependencies

*None.* This role can be applied standalone.

## Example Playbook

```yaml
- hosts: all
  become: true
  vars:
    journald_system_max_use: "1G"
    logrotate_rules:
      - name: nginx
        paths:
          - /var/log/nginx/*.log
        options:
          rotate: 52
          daily: true
          compress: true
          sharedscripts: true
          postrotate: |
            if [ -f /var/run/nginx.pid ]; then
              kill -USR1 `cat /var/run/nginx.pid`
            fi
  roles:
    - common
```

## Handlers

- **reload logrotate timer settings**: Reloads the systemd timer for logrotate.
- **test logrotate configuration**: Validates new logrotate rule templates.
- **restart journald**: Restarts systemd-journald service to apply configuration changes.
