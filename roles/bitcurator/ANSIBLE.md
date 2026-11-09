# bitcurator (Ansible role reference)

Install and configure a BitCurator workstation on Ubuntu Jammy.

This file is for operators. People who use the desktop should read
[README.md](README.md), which assumes no Ansible.

This role is intended for BitCurator hosts. It creates the BitCurator administrative user, installs required Ubuntu packages, downloads and installs BitCurator CLI and supporting tools, deploys helper scripts, configures basic XFCE power settings, and prepares common mount points. This effectively re-writes [Bitcurator-salt](https://github.com/bitcurator/bitcurator-salt)

## What this role does

- Enables the Ubuntu `universe` and `multiverse` repositories
- Installs BitCurator-related Ubuntu packages
- Installs optional Python packages
- Creates the BitCurator admin user and group (UID/GID 1000 by default, matching a clean upstream install) and adds `bitcurator_admin_group_members` to that group
- Sets the admin password when provided
- Configures XFCE power management for the admin user
- Downloads and installs:
  - BitCurator CLI
  - Bagger
  - DROID
  - Siegfried
- Installs workstation helper scripts into the desktop scripts directory
- Creates common mount points:
  - `/mnt/data`
  - `/mnt/rbrr`
  - `/mnt/archives_bd`
  - `/mnt/raid`

## Requirements

- Ubuntu 22.04 (Jammy)
- Internet access from the managed host to download release artifacts
- Supporting roles available in the same Ansible repository:
  - `common`
  - `clamav`
  - `xrdp`

## Role Variables

### Commonly overridden

```yaml
admin_user: bcadmin
bitcurator_admin_uid: 1000
bitcurator_admin_gid: 1000
bitcurator_admin_group_members: []
bitcurator_shared_dir_mode: "2775"
admin_home: "/home/{{ admin_user }}"
apps_dir: "{{ admin_home }}/apps"
download_dir: /tmp/bitcurator
scripts_dir: "{{ admin_home }}/Desktop/scripts/code"

bitcurator_version: v3.0.0
bitcurator_install_theme: false
bitcurator_install_mode: "{{ 'dedicated' if bitcurator_install_theme | bool else 'addon' }}"
bagger_version: 2.8.1
droid_version: "6.9.14"
bitcurator_droid_url: "https://github.com/digital-preservation/droid/releases/download/{{ droid_version }}/droid-binary-{{ droid_version }}-bin.zip"
bitcurator_droid_checksum: "sha256:82eae61a216a1b33cd27f8ee673d871be805c7e60dec3b18c7d9bed47a913b0a"
siegfried_version: "1.11.4"
siegfried_deb_arch: "amd64"
siegfried_deb_url: "https://github.com/richardlehane/siegfried/releases/download/v{{ siegfried_version }}/siegfried_{{ siegfried_version }}-1_{{ siegfried_deb_arch }}.deb"
```

### Optional

admin_user_password: "{{ vault_admin_user_password }}"  
bitcurator_python_packages: []

`admin_user_password` should be provided as a hashed password, usually from vault.

## Default package lists

This role installs a base set of Ubuntu packages through APT using `bitcurator_apt_packages` and `bitcurator_dependencies`.

Examples include tools such as:

- `xmount`
- `antiword`
- `avfs`
- `dcfldd`
- `ewf-tools`
- `gddrescue`
- `guymager`
- `sleuthkit`
- `smartmontools`
- `testdisk`
- `vlc`

The exact package list is defined in `defaults/main.yml`.

## Helper scripts

This role installs helper scripts from `roles/bitcurator/files/` into:

```yaml
{{ scripts_dir }}
```

These scripts support common workstation workflows such as:

- acquiring digital archives
- mounting and unmounting storage
- generating reports
- validating bags
- copying files with rsync
- preparing processing directories

The script list is controlled by `bitcurator_helper_scripts` in `defaults/main.yml`.

## Dependencies

Declared role dependencies:

```yaml
dependencies:  

- role: common  
- role: clamav  
- role: xrdp
```

## Example Playbook

---

```yaml
- name: BitCurator Environment Setup  
  hosts: bitcurator_hosts  
  remote_user: pulsys  
  become: true  

  vars_files:  

  - ../group_vars/bitcurator/shared.yml  
  - ../group_vars/bitcurator/vault.yml  

  roles:  

  - bitcurator
```

## Example Group Variables

---  

admin_user: bcadmin  
admin_user_password: "{{ vault_admin_user_password }}"  
admin_home: "/home/{{ admin_user }}"  
download_dir: "/tmp/bitcurator"  
apps_dir: "{{ admin_home }}/apps"  
bitcurator_version: "v3.0.0"  
bagger_version: "2.8.1"  
droid_version: "6.9.14"

## Files and directories created

Examples of paths created or managed by this role:

- `{{ admin_home }}`
- `{{ admin_home }}/Desktop`
- `{{ apps_dir }}`
- `{{ scripts_dir }}`
- `{{ admin_home }}/.config/xfce4/xfconf/xfce-perchannel-xml`
- `/var/lib/bitcurator/.installed`

## Notes

- `{{ admin_home }}/Desktop`, `{{ apps_dir }}` and `{{ scripts_dir }}` are group-writable with setgid (`bitcurator_shared_dir_mode`), so members of the admin group can work in them and new files stay in that group.
- The installer runs in upstream `addon` mode unless `bitcurator_install_theme` is true. `dedicated` mode adds the BitCurator theme, whose `xhost +` and `dconf load` steps need a logged-in X display and fail when run from Ansible on a headless xrdp host.
- `/etc/bitcurator-version` is written by the upstream installer (the distro release, e.g. `5.1.0`) and read back by `bitcurator version` and `bitcurator upgrade`; the role leaves it alone.
- The installer is run with `--user={{ admin_user }}`. Without it the CLI configures `$SUDO_USER`, which under `become` is the connecting account, not the BitCurator user.
- BitCurator CLI installation is guarded by a local marker file at `/var/lib/bitcurator/.installed`.
- Bagger, DROID, and Siegfried are installed from upstream release artifacts rather than Ubuntu packages.
- The role currently includes a `theme.yml` task file pattern in earlier planning, but the current task layout shown here does not actively use a theme task.
- Several legacy files remain in `roles/bitcurator/files/`; only scripts referenced by `bitcurator_helper_scripts` are installed by the role.
