# linux_gateway_nat

Configure a Linux host as an IPv4 gateway between two networks with packet forwarding and source NAT using `MASQUERADE`.

## What it does

- enables `net.ipv4.ip_forward=1`
- installs a managed iptables rules script
- applies stateful `FORWARD` rules between the internal and external interfaces
- always applies `MASQUERADE` in `POSTROUTING` for the internal subnet
- installs a systemd oneshot unit so the rules are re-applied on boot

## Requirements

- Linux host using systemd
- `ansible.posix` collection available for the `sysctl` task
- root privileges on the target host

## Role Variables

### Required

```yaml
gateway_nat_internal_interface: enp2s0
gateway_nat_external_interface: enp1s0
gateway_nat_internal_cidr: 192.168.48.0/24
```

### Optional

```yaml
gateway_nat_external_cidr: 192.168.1.0/24
gateway_nat_enable_ipv4_forwarding: true
gateway_nat_bidirectional_forward: false
gateway_nat_install_iptables: true
gateway_nat_manage_service: true
gateway_nat_rules_script_path: /usr/local/sbin/gateway-nat-rules.sh
gateway_nat_service_name: gateway-nat-rules.service
gateway_nat_extra_forward_rules: []
```

## Example Play

```yaml
- name: Configure Linux gateway NAT
  hosts: linux_gateways
  become: true
  collections:
    - ansible.posix
  roles:
    - role: linux_gateway_nat
      vars:
        gateway_nat_internal_interface: enp2s0
        gateway_nat_external_interface: enp1s0
        gateway_nat_internal_cidr: 192.168.48.0/24
        gateway_nat_external_cidr: 192.168.1.0/24
```

## Verification

```bash
sysctl net.ipv4.ip_forward
iptables -S FORWARD
iptables -t nat -S POSTROUTING
systemctl status gateway-nat-rules.service
```

## Notes

- This role does not manage interface IP configuration.
- This role does not set default `FORWARD` policy to `DROP`; it only adds allow rules.
- This role prefers a stateful internal-to-external model by default.
- NAT behavior is always `MASQUERADE`; there is no fixed-SNAT mode.
