# GlobalProtect Updater

Installs, compiles, and schedules a Rust utility to resolve GlobalProtect gateway domains into IP ranges for [Nginx/OpenResty](../openresty) trust lists.

## Description

The `globalprotect_updater` role performs the following actions:

1. **Installs the Rust toolchain** (via `pkgng` for FreeBSD).

2. **Compiles a custom Rust utility** from source code provided in the role.

3. **Deploys the binary** to a standard system path.

4. **Configures a Cron job** to run the updater periodically.

5. **Manages log files** and directory structures for the tool.

The utility itself resolves multiple regional GlobalProtect domains, identifies their /24 network blocks, and generates an Nginx configuration file containing `set_real_ip_from` directives. It includes safety checks, such as backing up existing configs and running `nginx -t` before reloading.

## Requirements

- **OS:** FreeBSD (configured in `meta/main.yml`).

- **Ansible:** 2.14 or higher.

- **Permissions:** Must be run as a user with `root` privileges to install packages and manage system binaries.

## Role Variables

The following variables are defined in `defaults/main.yml`:

| **Variable**               | **Default Value**                      | **Description**                                               |
| -------------------------- | -------------------------------------- | ------------------------------------------------------------- |
| `gp_updater_install_dir`   | `/opt/globalprotect-updater`           | Directory where source code is stored and compiled.           |
| `gp_updater_binary`        | `/usr/local/bin/globalprotect-updater` | Target path for the compiled binary.                          |
| `gp_updater_log`           | `/var/log/globalprotect-updater.log`   | Path for the execution logs.                                  |
| `gp_updater_cron`          | `minute: "*/15", hour: "*"`            | How often the updater runs.                                   |
| `gp_updater_static_ips`    | *(List of 3 IPs)*                      | A list of static CIDRs to always include in the Nginx config. |
| `gp_updater_nginx_include` | `/usr/local/etc/openresty/conf.d/...`  | Path where the generated Nginx config is written.             |

## Dependencies

None.

## Example Playbook

Tight coupling with [OpenResty](../openresty)

```yaml
- hosts: load_balancers
  roles:
    - role: lego
    - role: globalprotect_updater
    - role: openresty
      vars:
        gp_updater_cron:
          minute: "0"
          hour: "*/2"
```

## Internal Tool Details

The Rust source code (located in `files/main.rs`) handles the heavy lifting:

- **Domain Discovery:** It iterates through a list of global regions (e.g., `us-east-g`, `canada-east`) combined with a domain pattern.

- **CIDR Generation:** It creates /32 or /128 entries for specific resolutions and /24 blocks for IPv4 ranges to ensure narrow but reliable trust scoping.

- **Atomicity:** It tests the Nginx configuration before reloading. If the generated config is invalid, it restores a backup.

## License

MIT
