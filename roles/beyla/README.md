# Beyla

Installs and configures [Grafana Beyla](https://www.google.com/search?q=https://grafana.com/oss/beyla/), an eBPF-based auto-instrumentation tool that captures application observability metrics and traces without requiring code modifications. This role downloads the specified release, configures the service to export telemetry to an OpenTelemetry (OTLP) endpoint, and manages the Beyla systemd service.

## Requirements

- **Privileges**: Root access is required, as eBPF needs elevated permissions to attach to application processes and network sockets.

- **Dependencies**: Ensure `tar` is installed on the target machine to unarchive the release.

## Role Variables

The following variables are defined in `defaults/main.yml` and can be overridden to customize the installation and configuration.

### Core Configuration

| **Variable**          | **Default** | **Description**                                                                   |
| --------------------- | ----------- | --------------------------------------------------------------------------------- |
| **`beyla_enabled`**   | `false`     | Main toggle for the role. Must be set to `true` to install and configure Beyla. |
| **`beyla_version`**   | `"3.15.0"`  | The version of Grafana Beyla to download and install.                             |
| **`beyla_user`**      | `root`      | System user to run the Beyla systemd service. (Requires eBPF/proc access).        |
| **`beyla_group`**     | `root`      | System group to run the Beyla systemd service.                                    |
| **`beyla_log_level`** | `info`      | The logging verbosity for the Beyla daemon.                                       |

### Telemetry Export (OTLP)

| **Variable**              | **Default**                                 | **Description**                                                                                    |
| ------------------------- | ------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| **`beyla_otlp_endpoint`** | `"http://127.0.0.1:4318"`                   | The OTLP endpoint where traces and metrics will be sent (usually a local OpenTelemetry Collector). |
| **`beyla_otlp_protocol`** | `"http/protobuf"`                           | The protocol used for OTLP exports.                                                                |
| **`beyla_service_name`**  | `"{{ inventory_hostname }}"`                | Defines the `service.name` resource attribute.                                                     |
| **`beyla_environment`**   | `"{{ runtime_env \| default('staging') }}"` | Defines the `deployment.environment` resource attribute.                                           |

### Discovery Selection

Beyla needs to know which processes or ports to instrument. You can provide these via open ports or executable names.

| **Variable**                 | **Default** | **Description**                                                                                            |
| ---------------------------- | ----------- | ---------------------------------------------------------------------------------------------------------- |
| **`beyla_open_ports`**       | `[]`        | List of target local listener ports to instrument (e.g., `[80, 5432, 8983, 8080]`).                               |
| **`beyla_executable_names`** | `[]`        | List of explicit executable paths to monitor if port discovery is too broad (e.g., `['/usr/sbin/nginx']`). |

### Paths and Directories

| **Variable**            | **Default**             | **Description**                                    |
| ----------------------- | ----------------------- | -------------------------------------------------- |
| **`beyla_install_dir`** | `/opt/beyla`            | Base installation directory.                       |
| **`beyla_config_dir`**  | `/etc/beyla`            | Directory for Beyla configuration files.           |
| **`beyla_binary_path`** | `/usr/local/bin/beyla`  | Destination path for the executable binary.        |
| **`beyla_config_path`** | `/etc/beyla/config.yml` | Destination path for the main configuration file.  |
| **`beyla_env_path`**    | `/etc/default/beyla`    | Destination path for the systemd environment file. |

## Dependencies

It expects [otel_collector](../otel_collector/) to ship to Signoz

## Example Playbook

Here is an example of how to include and configure this role in your playbook to instrument a local NGINX server exporting to a local OpenTelemetry collector:

```yaml
- hosts: web_servers
  become: true
  vars:
    beyla_enabled: true
    beyla_version: "3.15.0"
    beyla_service_name: "nginx-frontend"
    beyla_environment: "production"
    beyla_open_ports:
      - 80
      - 443
    beyla_executable_names:
      - /usr/sbin/nginx

  roles:
    - role: beyla
```

## License

MIT-0 (No Attribution)

## Author Information

Princeton University Library
