# UFW Firewall Role

This Ansible role configures the Uncomplicated Firewall (UFW) on our Linux systems. It allows you to define allowed and denied networks and ports, making it easy to manage your firewall rules.

## Requirements

- Ansible 2.9 or higher
- Supported Operating Systems:
  - Rocky Linux (tested on 9)
  - Ubuntu (tested on jammy)

## Role Variables

the examples below allow ssh, http, and redis to those CIDR subnets. For ssh make sure you use the [defaults/main.yml](defaults/main.yml) example or you will lose access to your VM

```yaml
ufw_firewall_rules:
  - protocol: tcp
    source: 10.249.64.0/18
    port: 22
    action: ACCEPT
  - protocol: tcp
    source: 128.112.200.0/21
    port: 80
    action: ACCEPT
  - protocol: tcp
    source: 128.112.200.0/21
    port: 6379
    action: ACCEPT
```
