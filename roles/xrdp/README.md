# xrdp

Install and configure XRDP with an XFCE desktop on Ubuntu Jammy.

This role is intended for hosts that need remote desktop access over XRDP. It installs XRDP and Xorg backend packages, configures an XFCE-based session, disables sleep and power-management behaviors that interfere with remote sessions, optionally manages UFW access for the XRDP port, and enables the XRDP services.

## What this role does

- Disables `systemd-logind` idle and lid-switch suspend behaviors
- Masks system sleep targets:
  - `sleep.target`
  - `suspend.target`
  - `hibernate.target`
  - `hybrid-sleep.target`
- Installs XRDP and supporting packages
- Installs XFCE desktop packages for remote sessions
- Sets `xfce4-terminal` as the default terminal emulator
- Configures XFCE session defaults for XRDP users
- Disables XFCE power management, DPMS, and screen locking at the system level
- Configures XRDP listener and logging settings in `/etc/xrdp/xrdp.ini`
- Installs a managed `/etc/xrdp/startwm.sh` for launching XFCE components directly
- Optionally opens the XRDP port in UFW
- Enables and starts:
  - `xrdp`
  - `xrdp-sesman`

## Requirements

- Ubuntu 22.04 (Jammy)
- `apt` package management
- Systemd

## Role Variables

Defined in `defaults/main.yml`:

```yaml
xrdp_port: 3389

xrdp_manage_ufw: true
xrdp_ufw_allow_from:
  - 10.249.64.0/18
  - 10.249.0.0/18
  - 128.112.0.0/16
  - 172.20.80.0/22
  - 172.20.95.0/24
  - 172.20.192.0/19

xrdp_desktop: xfce

xrdp_packages_common:
  - dbus-x11
  - dbus-user-session
  - libpam-systemd
  - xorgxrdp
  - xrdp

xrdp_packages_xfce:
  - xfce4
  - xfce4-goodies
  - xfce4-screensaver
  - xfce4-session
  - xfce4-terminal
  - xfconf
```

## Variable Notes

### `xrdp_port`

TCP port XRDP listens on.

Default:

```yaml
xrdp_port: 3389
```

`xrdp_manage_ufw`

Whether the role creates a UFW allow rule for the XRDP port.

This is enabled by default. The `firewall` role sets a default-deny incoming
policy, so a remote desktop host that does not open this port cannot be reached
at all, and RDP clients report only a generic "cannot connect" error with no
indication that a firewall is responsible.

Default:

```yaml
xrdp_manage_ufw: true
```

`xrdp_ufw_allow_from`

List of networks permitted to reach the RDP port: campus wired plus both VPN
ranges, matching the networks trusted for SSH.

Default:

```yaml
xrdp_ufw_allow_from:
  - 10.249.64.0/18   # Princeton Wired Private
  - 10.249.0.0/18    # Princeton Wired Private-2
  - 128.112.0.0/16   # Princeton Wired
  - 172.20.80.0/22   # PU Subnet - LibNetPvt
  - 172.20.95.0/24   # Princeton VPN Subnet 1
  - 172.20.192.0/19  # Princeton VPN Subnet 2
```

If set to an empty list the role opens the port to any source, which is rarely
appropriate for a graphical login.

After starting the services the role waits for the RDP port to accept a local
connection, so a session manager that failed to start fails the play instead of
leaving a host that merely looks configured.

## Templates and Managed Files

This role manages:

- `/etc/xrdp/startwm.sh`
- `/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml`
- `/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml`
- `/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml`

It also updates `/etc/xrdp/xrdp.ini` using `ini_file` tasks.

## Session Behavior

The managed `startwm.sh` intentionally launches XFCE components directly instead of calling `xfce4-session`. This avoids logind/session issues seen under XRDP on Ubuntu 22.04 and provides a more reliable remote desktop startup path.

The role also disables screen blanking, DPMS, and screensaver locking to reduce remote-session interruptions.

## Handlers

This role defines handlers for:

- `restart xrdp`
- `restart gdm3`
- `restart logind`

## Example Playbook

```yaml
---  

- name: Configure XRDP host  
  hosts: xrdp_hosts  
  become: true  

  roles:  

  - role: xrdp
```

Example with custom firewall handling:

```yaml
---  

- name: Configure XRDP host  
  hosts: xrdp_hosts  
  become: true  

  roles:  

  - role: xrdp  
    vars:  
      xrdp_manage_ufw: true  
      xrdp_ufw_allow_from:  
        - 128.112.0.0/16  
      xrdp_port: 3389
```
