# UFW Firewall Role

This Ansible role configures the Uncomplicated Firewall (UFW) on Ubuntu systems. It allows you to define allowed and denied networks and ports, making it easy to manage your firewall rules.

## Requirements

- Ansible 2.9 or higher
- Supported Operating Systems:
    - Rocky Linux (tested on 9)
    - Ubuntu (tested on jammy)

## Role Variables

| Variable | Default | Description |
|---|---|---|
| `ufw_firewall_allowed_networks` | `[]` | List of networks to allow (CIDR notation or single IP addresses) |
| `ufw_firewall_allowed_ports` | `[]` | List of ports to allow (each item can be a dictionary with `port` and optional `proto` keys) |
| `ufw_firewall_denied_networks` | `[]` | List of networks to deny (CIDR notation or single IP addresses) |
| `ufw_firewall_denied_ports` | `[]` | List of ports to deny (each item can be a dictionary with `port` and optional `proto` keys) |

