# Firewall role

The `firewall` role applies a common host-security baseline to Debian/Ubuntu
and Red Hat/Rocky systems. It replaces the former `ufw_firewall` role.

The role:

- configures UFW on Debian-family hosts and firewalld on Red Hat-family hosts;
- restricts SSH and HTTP to approved networks;
- optionally permits BigFix and CheckMK;
- disables IPv4 and IPv6 ICMP redirects and adds runtime DROP rules; and
- installs and configures fail2ban for SSH.

## Important variables

```yaml
allowed_admin_cidrs: []
allowed_libnet_cidrs: []
ssh_allowed_cidrs: []

ufw_default_incoming: deny
ufw_default_outgoing: allow
ufw_enable_now: true
firewalld_zone: public

firewall_allow_http: true
firewall_allow_bigfix: true
firewall_allow_checkmk: true
firewall_fail2ban_enabled: true
```

Service-specific rules can be supplied through group variables:

```yaml
firewall_additional_rules:
  - port: 2181
    protocol: tcp
    source: 172.20.80.0/22
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
