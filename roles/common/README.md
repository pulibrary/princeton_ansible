# roles/common

## Description

The **common** role bootstraps our Linux servers with a standard baseline of tools, configurations, and services used across our infrastructure. It ensures a consistent environment by installing essential packages, setting up shell/editor configs, implementing a flexible, hierarchical log rotation system for application logs, managing systemd journal log disk usage, configuring optimized package mirrors with intelligent fallbacks, and deploying observability tools.

## Features

- **Package Repository Management**
  - Configures Princeton mirror (`mirror.math.princeton.edu`) as the preferred package source for faster downloads on campus.
  - Architecture-aware mirror selection (Princeton mirror only used for x86_64/amd64 systems).
  - Graceful fallback to Ubuntu archives (`archives.ubuntu.com`) when Princeton mirror is unavailable or unsupported.
  - Implements resilient error handling for network failures without blocking deployments.
  - Supports both RHEL (Rocky Linux) and Debian/Ubuntu package mirrors.
- **Package Installation**
  - Installs shared packages (`curl`, `git`, `htop`, `jq`, `tmux`, `vim`, etc.) on all hosts.
  - Installs OS-specific packages for Debian/Ubuntu and RHEL families.
- **Shell & Editor Configuration**
  - Deploys a global `tmux` configuration (`/etc/tmux.conf`).
  - Creates `/etc/vim/vimrc.local` for Vim customizations.
  - Enables timestamped bash history globally via `/etc/profile.d/`.
- **SSH Key Management**
  - Fetches public keys from GitHub for operations, library, CDH, and EAL teams.
- **Journal Log Management**
  - Configures systemd journal log disk usage limits via `/etc/systemd/journald.conf.d/`.
  - Prevents journal logs from consuming excessive disk space.
  - Automatically restarts `journald` when settings are changed.
- **Log Rotation**
  - Creates a systemd timer override to periodically check log sizes and trigger rotations.
  - Defines **global defaults** (`logrotate_global_defaults`) and **custom rules** (`logrotate_rules`) for `/etc/logrotate.d/`.
  - Includes CheckMK agent integration for monitoring logrotate health.
- **Observability & Utilities**
  - Installs [dua-cli](https://github.com/Byron/dua-cli/) for fast disk usage reporting.
  - Integrates with CheckMK for infrastructure monitoring.

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

### Mirror Configuration

The role automatically configures optimized package mirrors with intelligent fallback behavior.

| Variable            | Default                                                                 | Description                                                  |
| ------------------- | ----------------------------------------------------------------------- | ------------------------------------------------------------ |
| `preferred_mirrors` | `[{ name: "princeton", base: "mirror.math.princeton.edu", priority: "00" }]` | List of preferred mirrors with priority ordering.            |

#### How Mirror Selection Works

1. **Architecture Detection**: The role automatically detects the system architecture.
2. **Princeton Mirror (x86_64/amd64 only)**:
   - Used as the primary source on supported architectures for faster downloads.
   - Repository entries restricted with `[arch=amd64]` to prevent architecture mismatches.
3. **Ubuntu Archives (all architectures)**:
   - Configured as fallback with priority `99` on all systems.
   - Used exclusively on ARM64 systems (e.g., GitHub Actions runners).
4. **Graceful Degradation**: If Princeton mirror is unreachable, apt automatically uses Ubuntu archives.

#### Error Handling

The role uses `failed_when` conditions to gracefully handle mirror unavailability without blocking playbook execution. Only these network-related errors are tolerated:

- `does not have a Release file` - Repository not found/accessible
- `Failed to fetch` - Network download failures
- `Connection failed` - TCP connection issues
- `Unable to connect` - General connectivity problems
- `Could not resolve` - DNS resolution failures

All other errors (permissions, syntax, etc.) will still fail the playbook as expected.

**Example:** Add a secondary mirror in `defaults/main.yml`:

```yaml
preferred_mirrors:
  - name: princeton
    base: mirror.math.princeton.edu
    priority: "00"
  - name: library-mirror
    base: pulmirror.princeton.edu
    priority: "10"
```

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
| `logrotate_rules`           | `[ - name: "falcon-sensor" … ]`      | List of custom logrotate jobs for `/etc/logrotate.d/`. |

The role provides a flexible, hierarchical approach to log rotation:

1. **Global Defaults** (`logrotate_global_defaults`): Base settings applied across all rules.
2. **Per-Service Rules** (`logrotate_rules`): Specific configurations that inherit from global defaults.

Each rule in `logrotate_rules` can override any global default. Customize logrotate per service or environment by overriding `logrotate_rules` in `group_vars`.

**Example:** Configure nginx log rotation in `group_vars/webservers/vars.yml`:

```yaml
logrotate_rules:
  - name: "nginx-access"
    paths:
      - "/var/log/nginx/access.log"
    options:
      rotate: 30                # Keep 30 rotated logs
      maxsize: "5000M"          # Rotate when log exceeds 5GB
      create_mode: "0644"
      create_owner: "www-data"
      create_group: "www-data"
      su_user: "www-data"
      su_group: "www-data"
      postrotate: |
        if [ -f /var/run/nginx.pid ]; then
          kill -USR1 `cat /var/run/nginx.pid`
        fi
  - name: "nginx-error"
    paths:
      - "/var/log/nginx/error.log"
    options:
      rotate: 14
      maxsize: "500M"
      create_mode: "0644"
      create_owner: "www-data"
      create_group: "www-data"
      su_user: "www-data"
      su_group: "www-data"
      postrotate: |
        if [ -f /var/run/nginx.pid ]; then
          kill -USR1 `cat /var/run/nginx.pid`
        fi
```

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
          maxsize: "2000M"
          create_mode: "0644"
          create_owner: "www-data"
          create_group: "www-data"
          su_user: "www-data"
          su_group: "www-data"
          postrotate: |
            if [ -f /var/run/nginx.pid ]; then
              kill -USR1 `cat /var/run/nginx.pid`
            fi
  roles:
    - common
```

## Troubleshooting

### Mirror Issues

**Problem**: Playbook fails with "Failed to fetch" errors from Princeton mirror.

**Solution**: The role should handle this automatically with fallback to Ubuntu archives. If you see persistent failures:

1. Check if the error is in the list of tolerated conditions in `mirrors.yml`
2. Verify network connectivity: `curl -I https://mirror.math.princeton.edu/pub/ubuntu/`
3. Check configured repositories: `ls -la /etc/apt/sources.list.d/`

**Problem**: ARM64 systems (GitHub Actions) getting 404 errors from Princeton mirror.

**Solution**: This is automatically handled by architecture detection. Princeton mirror is only configured for x86_64/amd64 systems. Verify with:

```bash
ansible-playbook -i inventory site.yml --tags update_hostname --check -vvv
```

### Log Rotation Issues

**Problem**: Logs not rotating as expected.

**Solution**:

1. Test logrotate configuration manually:

   ```bash
   sudo logrotate -d /etc/logrotate.d/your-rule
   ```

2. Check logrotate timer status:

   ```bash
   sudo systemctl status logrotate.timer
   ```

3. View CheckMK monitoring output:

   ```bash
   sudo /usr/lib/check_mk_agent/local/logrotatecheck.sh
   ```

### Journal Log Issues

**Problem**: Journal logs consuming too much disk space.

**Solution**:

1. Check current usage:

   ```bash
   sudo journalctl --disk-usage
   ```

2. Verify configuration:

   ```bash
   cat /etc/systemd/journald.conf.d/00-journal-size.conf
   ```

3. Manually vacuum old logs:

   ```bash
   sudo journalctl --vacuum-size=800M
   ```

## Handlers

- **reload logrotate timer settings**: Reloads the systemd timer for logrotate.
- **test logrotate configuration**: Validates new logrotate rule templates.
- **restart journald**: Restarts systemd-journald service to apply configuration changes.

## Testing

To test the role in isolation:

```bash
# Test on a specific host
ansible-playbook playbooks/utils/common_only.yml --limit testhost.princeton.edu

# Check mode (dry run)
ansible-playbook playbooks/utils/common_only.yml --limit testhost.princeton.edu --check

# Test mirror configuration only
ansible-playbook playbooks/utils/common_only.yml --limit testhost.princeton.edu  -vvv | grep -A 20 "mirror"
```

## License

Princeton University Library

## Author Information

Princeton University Library
