# UFW Firewall Role

This Ansible role configures the Uncomplicated Firewall (UFW) on our Linux systems. It allows you to define allowed and denied networks and ports, making it easy to manage your firewall rules. Further descriptions of the networks will be on [IT-Handbook](https://github.com/pulibrary/pul-it-handbook)

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
    source: "{{ ufw_campus_and_vpn }}"
    port: 80
    action: ACCEPT
  - protocol: tcp
    source: "{{ ufw_libnet }}"
    port: 22
    action: ACCEPT
```
