# Firewall role

The `firewall` role applies a common host-security baseline to Debian/Ubuntu
and Red Hat/Rocky systems. It replaces the former `ufw_firewall` role.

The role:

- configures UFW on Debian-family hosts and firewalld on Red Hat-family hosts;
- allows all traffic from trusted networks;
- restricts SSH and HTTP to approved networks;
- optionally permits BigFix, CheckMK, and remote desktop;
- disables IPv4 and IPv6 ICMP redirects and adds runtime DROP rules; and
- installs and configures fail2ban for SSH.

## Important variables

```yaml
allowed_admin_cidrs: []
allowed_libnet_cidrs: []
ssh_allowed_cidrs: []

firewall_trusted_cidrs:
  - 172.20.80.0/22
  - 128.112.203.146/32
  - 128.112.200.245/32
  - 128.112.201.34/32

ufw_default_incoming: deny
ufw_default_outgoing: allow
ufw_enable_now: true
firewalld_zone: public

firewall_allow_http: true
firewall_allow_bigfix: true
firewall_allow_checkmk: true
firewall_allow_rdp: false
firewall_fail2ban_enabled: true
```

## Remote desktop

`firewall_allow_rdp` opens `firewall_rdp_port` (3389) to `firewall_rdp_cidrs`:
campus wired plus both VPN ranges, matching the networks trusted for SSH.

It is off by default so only hosts that actually serve a desktop expose the
port. The `xrdp` role depends on this role and switches it on, so applying
`xrdp` is enough:

```yaml
# roles/xrdp/meta/main.yml
dependencies:
  - role: firewall
    firewall_allow_rdp: true
```

`firewall_trusted_cidrs` does not make this redundant: it permits the library
private subnet and the load balancers, not the VPN ranges staff connect from.

## Trusted networks

`firewall_trusted_cidrs` opens **every port** to the listed sources, rather than
the specific services permitted by the other variables. It covers the LibNetPvt
subnet and the production load balancers, and applies to all hosts.

This rule previously existed only in the ZooKeeper group variables, so
otherwise identical hosts enforced different policy depending on which group
they happened to be in. Because each entry grants unrestricted access, keep the
list short and prefer a service-specific rule where one will do.

To narrow or extend it for a group, override the list in that group's variables:

```yaml
# group_vars/<group>/common.yml
firewall_trusted_cidrs:
  - 172.20.80.0/22
```

Service-specific rules can be supplied through group variables:

```yaml
firewall_additional_rules:
  - source: 172.20.80.0/22
    comment: PU Subnet - LibNetPvt
```

The SSH allow rules are created before UFW is enabled or unrestricted
firewalld SSH access is removed.

## Example

```yaml
- name: Configure host firewall
  hosts: servers
  become: true
  roles:
    - role: roles/firewall
```

Run the utility playbook with an explicit inventory limit:

```shell
ansible-playbook playbooks/utils/ufw_firewall.yml --limit my-host
```
