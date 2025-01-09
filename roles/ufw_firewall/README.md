## UFW Firewall Role

The `ufw_firewall` Ansible role configures UFW (Uncomplicated Firewall) to allow or deny traffic to specified networks and ports based on dynamic, parameterized variables. It supports flexible definitions of allowed networks and ports, enabling easy customization for specific environments, such as campus networks or library systems.

This role dynamically generates UFW rules, sets default policies, and ensures outgoing traffic is allowed while controlling incoming traffic as specified.

***

## Features

1. **Dynamic Rule Generation**:

   * Define firewall rules based on networks and ports using variables.
   * Parametrize ports for different services (e.g., `ssh`, `web`) for easy reuse and customization.

2. **Default Policies**:

   * Allows outgoing traffic by default.
   * Drops all other incoming traffic unless explicitly permitted.

3. **Template-Driven Configuration**:

   * Generates UFW rules dynamically using Jinja2 templates.
   * Supports multiple network groups (e.g., `campus_and_vpn` and `libnet`).

4. **Customizable Ports**:

   * Easily update port numbers for specific services like `SSH` or `HTTP` using variables.

***

## Requirements

* Ansible >= 2.9
* Target system running a UFW-compatible operating system (e.g., Ubuntu)

***

## Role Variables

The role uses the following variables for customization:

### 1. **Network Definitions**

Define the networks [All defined here][../../group_vars/all/vars.yml] you want to allow traffic from, grouped logically by purpose:

```yaml
ufw_campus_and_vpn:
  - name: "Princeton Wired Private"
    network: 10.249.64.0/18
  - name: "Princeton VPN Subnet 1"
    network: 172.20.95.0/24

ufw_libnet:
  - name: "PU Subnet - LibNet"
    network: 128.112.200.0/21
```

### 2. **Ports**

Specify the ports for each service:

```yaml
ufw_firewall_ports:
  ssh: 22
  web: 5342  # Replace with the port for your web service
```


## Usage

### Example Playbook

```yaml
---

    - hosts: servers
      roles:
         - { role: roles/ufw_firewall }
```

***

## Verification

To verify the configuration, you can:

1. Check UFW status on endpoint:

   ```bash
   sudo ufw status verbose
   ```

2. Inspect iptables rules on endpoint:

   ```bash
   sudo iptables -L -n -v
   ```
