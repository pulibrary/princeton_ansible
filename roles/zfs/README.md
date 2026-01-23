# zfs (OpenZFS)

Installs and configures **OpenZFS** on supported Linux distributions and enforces a **single ZFS pool named `tank`**.

This role can also:

- configure ARC tuning parameters (`zfs_arc_max`, `zfs_arc_min`)
- create the `tank` pool
- create datasets under `tank/*`
- install a systemd scrub timer/service for `tank`
- deploy a monitoring script and register it with CheckMK MRPE

> ⚠️ Storage warning: pool creation/destruction is destructive if misconfigured. Review `devices` carefully.

---

## Supported platforms

- **Debian-family** (Ubuntu/Debian via `apt`)
- **RedHat-family** (Rocky/Alma/RHEL via EPEL + ZFS repo RPM)

---

## Design constraints (enforced)

### Pool name MUST be `tank`

The role will **fail fast** if you attempt:

- any pool name other than `tank`
- any dataset not under the `tank` pool

 > **This is intentional:** the scrub service and local conventions are standardized around `tank`.

---

## What the role does

### 1) Install packages

- On **RedHat**:
  - installs `epel-release`
  - installs ZFS repo RPM from `zfs_repo_url`
  - installs kernel build deps (`zfs_devel_packages`)
  - installs `zfs_packages`
  - enables ZFS systemd units (`zfs_services`)
- On **Debian**:
  - installs `zfs_packages`

### 2) ARC tuning (optional)

If either `zfs_arc_max` or `zfs_arc_min` is set, the role writes `/etc/modprobe.d/zfs.conf` using `human_to_bytes` so values like `8G` become bytes.

**Applying changes safely**

- On first run: options are written *before* loading the module, so they apply immediately.
- If ARC values change later:
  - If **no pools exist**, the role will do a **best-effort safe reload** of the `zfs` module (default behavior).
  - If **pools exist**, the role will **not** reload the module (safety) and will print a message indicating a reboot/maintenance reload is required.

### 3) Load the kernel module and persist at boot

- Loads `zfs` via `modprobe` (unless `zfs_load_module: false`)
- Ensures module loads at boot via `/etc/modules-load.d/zfs.conf`

### 4) Pool management (optional)

If `zfs_pools` is set:

- creates the pool using `zpool create ...`
- pool creation is **idempotent**: the role checks `zpool list` and only creates when missing.

#### Pool destroy (opt-in)

If a pool item has `state: absent`, the role will only destroy it when:

```yaml
zfs_allow_pool_destroy: true
```

This is intentionally guarded.

### 5) Dataset management (optional)

If `zfs_datasets` is set:

- creates/updates datasets via community.general.zfs

- merges zfs_default_dataset_properties with per-dataset properties

- only acts when the pool exists

### 6) Scrub timer (default enabled)

If zfs_enable_scrub: true, installs:

- `/etc/systemd/system/zfs-scrub.service` (scrubs tank)

- `/etc/systemd/system/zfs-scrub.timer`

Timer schedule is controlled via zfs_scrub_calendar.

### 7) Monitoring (default enabled)

If zfs_monitoring_enabled: true:

- deploys the monitoring script to zfs_monitoring_script_path

- registers it in `/etc/check_mk/mrpe.cfg` (always; no CheckMK-local-fact requirement)

- attempts to restart check-mk-agent best-effort (won’t fail the role if absent)

## Role variables

### Behavior toggles

```yaml
zfs_load_module: true
zfs_safe_reload_module_on_arc_change: true
zfs_allow_pool_destroy: false
```

## Packages (overrideable)

```yaml
zfs_packages: []        # populated from OS defaults unless overridden
zfs_devel_packages: []  # populated for RedHat unless overridden
zfs_services: []        # populated for RedHat unless overridden
zfs_repo_url: ""        # populated for RedHat unless overridden
```

### Pool configuration (ENFORCED: must be tank)

```yaml
zfs_pools: []
# Example:
# zfs_pools:
#   - name: tank
#     devices:
#       - /dev/sdb
#     properties:
#       ashift: 12
#       autoexpand: on
#     state: present
```

#### Dataset configuration (ENFORCED: must be tank/*)

```yaml
zfs_datasets: []
# Example:
# zfs_datasets:
#   - name: tank/nfs
#     properties:
#       mountpoint: /var/nfs
#       compression: lz4
#     state: present

zfs_default_dataset_properties:
  compression: lz4
  atime: off
  relatime: on
  xattr: sa
```

#### Scrub timer

```yaml
zfs_enable_scrub: true
zfs_scrub_calendar: "monthly"
```

#### ARC tuning

```yaml
zfs_arc_max: ""   # e.g. "8G"
zfs_arc_min: ""   # e.g. "2G"
```

#### Monitoring

```yaml
zfs_monitoring_enabled: true
zfs_monitoring_script_path: /usr/local/bin/check_zfs.sh
```

## Example usage

### Install ZFS only (most common)

```yaml
- hosts: zfs_hosts
  become: true
  roles:
    - role: zfs
```

### Install + create tank + datasets + weekly scrub + ARC tuning

```yaml
- hosts: zfs_hosts
  become: true
  roles:
    - role: zfs
      vars:
        zfs_arc_max: "8G"
        zfs_arc_min: "2G"

        zfs_pools:
          - name: tank
            devices:
              - /dev/sdb
            properties:
              ashift: 12
              autoexpand: on
            state: present

        zfs_datasets:
          - name: tank/nfs
            properties:
              mountpoint: /var/nfs
            state: present

        zfs_scrub_calendar: "weekly"
```
