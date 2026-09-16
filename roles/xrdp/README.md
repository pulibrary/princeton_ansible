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

### `xrdp_listen_address`

Address the listener binds to. Empty is the packaged behaviour, every interface,
and is what a desktop reached directly by an RDP client needs.

Default:

```yaml
xrdp_listen_address: ""
```

**xrdp has no `address` setting.** The bind address is part of the port value,
in the form `tcp://<address>:<port>`. Adding an `address` key to `[Globals]`
looks right, is accepted without complaint, and does nothing, so a host
configured that way keeps listening on every interface. This role composes the
port value for you:

| `xrdp_listen_address` | rendered `xrdp.ini` | binds to |
| --- | --- | --- |
| `""` (default) | `port=3389` | every interface |
| `127.0.0.1` | `port=tcp://127.0.0.1:3389` | loopback only |

Set it to `127.0.0.1` on a host whose desktop is reached by forwarding the port
over SSH, which keeps the login window off the network entirely. See
[`xrdp_ca_login`](../xrdp_ca_login), which verifies the resulting socket rather
than trusting the setting.

IPv4 only: an IPv6 bind address needs the `tcp6://` form, which this does not
compose. Set `xrdp_listen_spec` directly for that.

### The firewall

This role depends on the `firewall` role and asks it to open the RDP port:

```yaml
# roles/xrdp/meta/main.yml
dependencies:
  - role: firewall
    firewall_allow_rdp: true
```

The firewall role denies incoming traffic by default, so without that rule a
remote desktop host cannot be reached at all and clients report only a generic
"cannot connect". Keeping the rule in the firewall role means host firewall
policy lives in one place, and applying this role now also applies the standard
firewall baseline.

The permitted sources are `firewall_rdp_cidrs` in the firewall role: campus
wired plus both VPN ranges, matching the networks trusted for SSH. Note that
`firewall_trusted_cidrs` does not cover this, since it permits the library
private subnet and the load balancers but not the VPN ranges staff connect from.

After starting the services this role waits for the RDP port to accept a local
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

Example restricting which networks may reach the RDP port. The permitted sources
belong to the firewall role, so override them there:

```yaml
---

- name: Configure XRDP host
  hosts: xrdp_hosts
  become: true

  roles:

  - role: xrdp
    vars:
      xrdp_port: 3389
      firewall_rdp_cidrs:
        - 128.112.0.0/16
```
