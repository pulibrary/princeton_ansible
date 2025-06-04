# Ansible Role: VictoriaLogs

[![Molecule CI](https://github.com/your-username/ansible-role-victorialogs/workflows/Molecule%20CI/badge.svg)](https://github.com/your-username/ansible-role-victorialogs/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Ansible role for installing and configuring VictoriaLogs on Ubuntu/Debian systems. VictoriaLogs is a fast, cost-effective and scalable logs database for VictoriaMetrics.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Role Variables](#role-variables)
- [Dependencies](#dependencies)
- [Example Playbooks](#example-playbooks)
- [Directory Structure](#directory-structure)
- [Testing](#testing)
- [Upgrade Process](#upgrade-process)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Requirements

- **Ansible**: >= 2.9
- **Operating System**: Ubuntu 20.04/22.04/24.04, Debian 10/11/12
- **Privileges**: sudo/root access on target hosts
- **Network**: Internet access for downloading VictoriaLogs binary

## Role Variables

### Default Variables

All variables are defined in `defaults/main.yml` and can be overridden:

```yaml
# VictoriaLogs version and download configuration
victorialogs_version: "v1.23.2-victorialogs"
victorialogs_download_url: "https://github.com/VictoriaMetrics/VictoriaMetrics/releases/download/{{ victorialogs_version }}/victoria-logs-linux-amd64-{{ victorialogs_version }}.tar.gz"
victorialogs_binary_name: "victoria-logs-prod"

# System user configuration
victorialogs_user: "victorialogs"
victorialogs_group: "victorialogs"

# Directory paths
victorialogs_install_dir: "/opt/victorialogs"
victorialogs_data_dir: "/var/lib/victorialogs"
victorialogs_config_dir: "/etc/victorialogs"

# Service configuration
victorialogs_http_listen_addr: ":9428"
victorialogs_logger_level: "INFO"
victorialogs_logger_format: "json"

```

### Variable Descriptions

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `victorialogs_version` | VictoriaLogs version to install | `v1.23.2-victorialogs` | No |
| `victorialogs_http_listen_addr` | HTTP server listen address | `:9428` | No |
| `victorialogs_logger_level` | Log level (DEBUG, INFO, WARN, ERROR) | `INFO` | No |
| `victorialogs_logger_format` | Log format (json, logfmt) | `json` | No |
| `victorialogs_data_dir` | Data storage directory | `/var/lib/victorialogs` | No |
| `victorialogs_user` | System user for VictoriaLogs | `victorialogs` | No |
| `victorialogs_group` | System group for VictoriaLogs | `victorialogs` | No |

## Dependencies

This role depends on the [roles/common](roles/common) role

## Example Playbooks

### Basic Installation

```yaml
---
- name: Install VictoriaLogs
  hosts: log
  become: true
  roles:
    - log
```

```

```

## Integration Examples

### With Prometheus

```yaml
# Add VictoriaLogs target to Prometheus
- job_name: 'victorialogs'
  static_configs:
    - targets: ['victorialogs-server:9428']
```

```

### Log Forwarding (Vector)

```toml
[sources.system_logs]
type = "file"
includes = ["/var/log/*.log"]

[sinks.victorialogs]
type = "http"
uri = "http://kennyloggin-server:9428/insert/jsonline"
inputs = ["system_logs"]
```
