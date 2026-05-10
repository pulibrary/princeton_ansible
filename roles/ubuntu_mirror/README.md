# Ubuntu Mirror

Sets up a local Ubuntu `apt` archive mirror. It utilizes the Debian community-standard `ftpsync` tool to ensure atomic updates and metadata consistency, manages storage via **ZFS**, and provides **Nginx** configuration for serving the repository.

## Features

- **Atomic Syncing**: Uses `ftpsync` (cloned from Debian's `archvsync`) to handle two-stage synchronization.

- **ZFS Integration**: Automatically creates and configures a ZFS dataset with compression (LZ4) for storage.

- **Automated Scheduling**: Installs a cron job and a shell wrapper for periodic updates.

- **Nginx Ready**: Generates a location-block drop-in for Nginx to serve the mirror.

- **Log Management**: Configures `newsyslog` for automatic log rotation.

## Requirements

- **Target OS**: FreeBSD (tested on version 15).

- **Storage**: A ZFS zpool must exist (default expects `pubmirror`).

- **Upstream Access**: The node must be able to reach upstream rsync mirrors (default is `dotsrc.org`).

## Dependencies

- `pulmirror`: This role is designed to integrate with a parent `pulmirror` role which manages the primary Nginx vhost.

## Role Variables

Settable variables are defined in `defaults/main.yml`.

### Storage & Ownership

| **Variable**            | **Default**                 | **Description**                               |
| ----------------------- | --------------------------- | --------------------------------------------- |
| `ubuntu_mirror_dataset` | `pubmirror/ubuntu`          | The ZFS dataset name to create.               |
| `ubuntu_mirror_root`    | `/usr/local/www/.../ubuntu` | The filesystem path where the mirror resides. |
| `ubuntu_mirror_owner`   | `www`                       | The user who owns the mirror files.           |

### Mirror Content

| **Variable**                  | **Default**                          | **Description**                              |
| ----------------------------- | ------------------------------------ | -------------------------------------------- |
| `ubuntu_mirror_upstream`      | `rsync://mirrors.dotsrc.org/ubuntu/` | The upstream rsync source.                   |
| `ubuntu_mirror_releases`      | `[jammy, noble]`                     | List of Ubuntu releases to mirror.           |
| `ubuntu_mirror_architectures` | `[amd64, arm64]`                     | CPU architectures to sync.                   |
| `ubuntu_mirror_components`    | `[main, restricted, ...]`            | Repository components (main, universe, etc). |

### Operational

| **Variable**              | **Default**              | **Description**                                 |
| ------------------------- | ------------------------ | ----------------------------------------------- |
| `ubuntu_mirror_bwlimit`   | `20000`                  | Bandwidth limit for rsync in KB/s.              |
| `ubuntu_mirror_cron_hour` | `*/6`                    | How often to run the sync job.                  |
| `ubuntu_mirror_email`     | `lsupport@princeton.edu` | Admin email included in the mirror trace files. |

## Example Playbook

```yaml
- hosts: mirror_servers
  become: yes
  roles:
    - role: pulibrary.ubuntu_mirror
      vars:
        ubuntu_mirror_releases:
          - focal
          - jammy
          - noble
        ubuntu_mirror_bwlimit: 50000
```

## Structure & Logic

1. **Storage**: The role ensures a ZFS dataset exists with `atime=off` and `compression=lz4` to optimize for small package file reads.

2. **Tooling**: Clones the `archvsync` repository to get the latest `ftpsync` logic.

3. **Sync Wrapper**: A shell script `sync-ubuntu-mirror.sh` uses FreeBSD's `lockf` to prevent overlapping sync runs.

4. **Web Access**: The Nginx drop-in creates an alias at `/mirror/ubuntu/` and a 301 redirect from `/ubuntu/` for user convenience.

## License

MIT-0
