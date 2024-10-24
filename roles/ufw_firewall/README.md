# UFW Firewall Role

This Ansible role configures the Uncomplicated Firewall (UFW) on our Linux systems. It allows you to define allowed and denied networks and ports, making it easy to manage your firewall rules.

## Requirements

- Ansible 2.9 or higher
- Supported Operating Systems:
  - Rocky Linux (tested on 9)
  - Ubuntu (tested on jammy)

## Role Variables

the examples below allow http and redis to those CIDR subnets

```yaml
ufw_firewall_rules:
  - service: http
    port: 80
    protocol: tcp
    allowed_cidrs:
      - 128.112.200.0/21
      - 128.112.0.0/16
  - service: redis
    port: 6379
    protocol: tcp
    allowed_cidrs:
      - 128.112.200.0/21
      - 128.112.0.0/16
```
