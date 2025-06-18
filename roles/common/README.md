# Common Role

Install all the tools our VMS have in Common

## Overview

Since we include logrotate in the role, we want other roles to have access to a highly flexible, hierarchical approach to managing log rotation across your infrastructure. It allows you to define logrotate rules at multiple levels of your Ansible inventory, from global defaults to host-specific configurations.

## Configuration Structure

### Variable Hierarchy

Variables can be defined at multiple levels with the following precedence (highest to lowest):

1. **Host Variables** (`host_vars/hostname.yml`)
2. **Group Variables** (`group_vars/group_name.yml`)
3. **Role Variables** (`roles/role_name/vars/main.yml`)
4. **Global Variables** (`group_vars/all.yml`)
5. **Role Defaults** (`roles/role_name/defaults/main.yml`)

### Global Defaults

The `logrotate_global_defaults` variable provides base settings that can be referenced throughout your configurations:

```yaml
logrotate_global_defaults:
  rotate: 4
  weekly: true
  missingok: true
  notifempty: true
  compress: true
  delaycompress: true
  copytruncate: false
  create_mode: "0644"
  create_owner: "root"
  create_group: "root"
  sharedscripts: false
  postrotate: ""
  prerotate: ""
```

### Logrotate Rules

Rules are defined in the `logrotate_rules` list variable. Each rule contains:

- **`name`** - The name of the logrotate configuration file (without .conf extension)
- **`paths`** - List of log file paths to rotate
- **`options`** - Dictionary of logrotate options

## Supported Logrotate Options

The template supports all major logrotate directives:

### Rotation Frequency

- `daily`, `weekly`, `monthly`, `yearly`
- `rotate` - Number of rotations to keep
- `size` - Rotate when file reaches this size
- `maxage` - Remove files older than this many days

### Compression

- `compress` / `nocompress`
- `delaycompress`

### File Handling

- `missingok` / `nomissingok`
- `notifempty` / `ifempty`
- `copytruncate` / `nocopytruncate`
- `create` - Create new log files with specified permissions
- `nocreate`

### Advanced Options

- `sharedscripts` / `nosharedscripts`
- `dateext` / `nodateext`
- `dateformat`
- `extension`
- `olddir` / `noolddir`
- `mail` / `nomail`
- `mailfirst` / `maillast`
- `maxsize` / `minsize`

### Script Hooks

- `prerotate` - Commands to run before rotation
- `postrotate` - Commands to run after rotation
- `firstaction` - Commands to run before all files are rotated
- `lastaction` - Commands to run after all files are rotated

## Usage Examples

### Basic Global Configuration

**`group_vars/app_name/environment.yml`**

```yaml
logrotate_rules:
  - name: "system-logs"
    paths:
      - "/var/log/syslog"
      - "/var/log/auth.log"
    options:
      rotate: 7
      daily: true
      compress: true
      missingok: true
      notifempty: true
      sharedscripts: true
      postrotate: |
        systemctl reload rsyslog || true
```

### Service-Specific Configuration

**`group_vars/webservers.yml`**

```yaml
logrotate_rules:
  - name: "nginx"
    paths:
      - "/var/log/nginx/*.log"
    options:
      rotate: 52
      daily: true
      compress: true
      delaycompress: true
      sharedscripts: true
      postrotate: |
        if [ -f /var/run/nginx.pid ]; then
          kill -USR1 `cat /var/run/nginx.pid`
        fi
```

### Using Global Defaults

You can reference the global defaults in your configurations:

```yaml
logrotate_rules:
  - name: "my-service"
    paths:
      - "/opt/app_name/current/log/*.log"
    options:
      rotate: "{{ logrotate_global_defaults.rotate }}"
      compress: "{{ logrotate_global_defaults.compress }}"
      daily: true
      postrotate: |
        systemctl reload myservice || true
```
