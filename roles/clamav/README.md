# Ansible Role: ClamAV

Installs and configures ClamAV antivirus on Debian/Ubuntu and RedHat/CentOS Linux servers.

Originally forked from [geerlingguy/ansible-role-clamav](https://github.com/geerlingguy/ansible-role-clamav).

## Requirements

None.

## Role Variables

### OS-Specific Variables (Auto-detected)

These variables are automatically set based on the target OS family and generally should not be overridden:

| Variable | Debian | RedHat |
|----------|--------|--------|
| `clamav_daemon_localsocket` | `/var/run/clamav/clamd.ctl` | `/var/run/clamd.scan/clamd.sock` |
| `clamav_daemon_config_path` | `/etc/clamav/clamd.conf` | `/etc/clamd.d/scan.conf` |
| `clamav_freshclam_daemon_config_path` | `/etc/clamav/freshclam.conf` | `/etc/freshclam.conf` |
| `clamav_daemon` | `clamav-daemon` | `clamd@scan` |
| `clamav_freshclam_daemon` | `clamav-freshclam` | `clamd-freshclam` |
| `clamav_packages` | `clamav`, `clamav-base`, `clamav-daemon` | `clamav`, `clamav-update`, `clamav-scanner-systemd`, `clamav-data` |

### Configurable Variables

```yaml
# ClamAV daemon service state and boot behavior
clamav_daemon_state: started
clamav_daemon_enabled: true

# Freshclam daemon service state and boot behavior
clamav_freshclam_daemon_state: started
clamav_freshclam_daemon_enabled: true
```

### Daemon Configuration

Configuration changes are applied via `lineinfile` to the ClamAV daemon config file:

```yaml
clamav_daemon_configuration_changes:
  - regexp: '^.*Example$'
    state: absent
  - regexp: '^.*LocalSocket .*$'
    line: 'LocalSocket {{ clamav_daemon_localsocket }}'
```

Each item supports:

- `regexp`: Pattern to match in the config file
- `line`: Replacement line (optional, omit for deletion)
- `state`: `present` (default) or `absent`

### Freshclam Configuration (Optional)

To configure freshclam (e.g., for proxy settings), define `clamav_freshclam_configuration_changes`:

```yaml
clamav_freshclam_configuration_changes:
  - regexp: '^.*HTTPProxyServer .*$'
    line: 'HTTPProxyServer proxy.example.com'
  - regexp: '^.*HTTPProxyPort .*$'
    line: 'HTTPProxyPort 3128'
```

## Dependencies

None.

## Example Playbook

Basic usage:

```yaml
- hosts: servers
  become: true
  roles:
    - clamav
```

With custom configuration:

```yaml
- hosts: servers
  become: true
  vars:
    clamav_daemon_configuration_changes:
      - regexp: '^.*Example$'
        state: absent
      - regexp: '^.*LocalSocket .*$'
        line: 'LocalSocket /var/run/clamav/clamd.ctl'
      - regexp: '^.*TCPSocket .*$'
        line: 'TCPSocket 3310'
      - regexp: '^.*MaxFileSize .*$'
        line: 'MaxFileSize 100M'
    clamav_freshclam_configuration_changes:
      - regexp: '^.*Checks .*$'
        line: 'Checks 12'
  roles:
    - clamav
```

## Handlers

| Handler | Description |
|---------|-------------|
| `restart clamav daemon` | Restarts the ClamAV daemon when configuration changes |

## Supported Platforms

- Ubuntu: xenial, bionic, jammy, noble
- Debian: jessie, stretch, bookworm
- RedHat/CentOS: Rocky Linux 9 (tested via Molecule)

## Testing

This role includes Molecule tests using Docker:

```bash
# Run with default distribution (Rocky Linux 9)
molecule test

# Run with a specific distribution
MOLECULE_DISTRO=ubuntu2204 molecule test
```

## License

MIT

## Author Information

Originally created by [Jeff Geerling](https://www.jeffgeerling.com/).
