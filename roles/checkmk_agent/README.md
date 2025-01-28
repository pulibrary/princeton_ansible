# Checkmk Agent Role
This Ansible role installs and configures the Checkmk agent on target hosts and registers them with a Checkmk server. It supports both Debian-based (e.g., Ubuntu) and RedHat-based (e.g., RHEL, CentOS) systems.

## Role Overview
The role performs the following tasks:

Registers the host with the Checkmk server.

Copies the Checkmk agent installer to the target host.

Installs the Checkmk agent based on the host's operating system.

Activates the changes on the Checkmk server.

### Requirements
Ansible 2.9 or higher.

Access to the Checkmk server and valid credentials (automation user and secret).

Checkmk agent installation files (.deb for Debian-based systems and .rpm for RedHat-based systems) are available in the files directory of the role.

### Role Variables
Below are the variables used by this role:

#### Required Variables
Variable Name	Description
`checkmk_agent_server`	The hostname or IP address of the Checkmk server.
`checkmk_agent_site`	The Checkmk site where the host will be registered.
`checkmk_agent_user`	The Checkmk automation username.
`checkmk_agent_secret`	The Checkmk automation secret (password).
`checkmk_agent_host_name`	The name of the host as it will appear in Checkmk.
`checkmk_agent_host_ip`	The IP address of the host to be monitored.
`checkmk_agent_version`	The version of the Checkmk agent to install (e.g., 2.3.0p15).
`checkmk_folder`	The folder in Checkmk where the host will be placed (default: /).
Optional Variables
Variable Name	Description
`checkmk_agent_server_protocol`	The protocol to use for communication with the Checkmk server (http or https). Default: http.
`checkmk_agent_server_port`	The port to use for communication with the Checkmk server. Automatically set based on the protocol.
`checkmk_agent_port`	The port used by the Checkmk agent (default: 6556).
`checkmk_agent_auto_activate`	Whether to automatically activate changes on the Checkmk server (default: false).
`checkmk_agent_discover`	Whether to enable service discovery on the host (default: false).
`checkmk_agent_tls`	Whether to enable TLS for agent communication (default: true).
`checkmk_agent_delegate_download`	The host to delegate the agent download to (default: inventory_hostname).

#### Tasks
The role performs the following tasks:

1. Register Host with Checkmk:

    * Uses the checkmk.general.host module to register the host with the Checkmk server.

2. Copy Agent Installer:

    * Copies the appropriate agent installer (.deb or .rpm) to the target host based on the operating system.

3. Install Agent:

    * Installs the agent using apt for Debian-based systems or dnf for RedHat-based systems.

4. Activate Changes on Checkmk Server:

    * Uses the checkmk.general.activation module to activate changes on the Checkmk server.

#### Usage
**Inventory Example**
Add the following variables to your inventory or group/host variables:


```yaml
checkmk_agent_server: "pulmonitor-staging1.princeton.edu"
checkmk_agent_site: "pulmonitor"
checkmk_agent_user: "ansible"
checkmk_agent_secret: "{{ vault_ansible_automation_secret }}"
checkmk_agent_host_name: "{{ inventory_hostname }}"
checkmk_agent_host_ip: "{{ ansible_default_ipv4.address }}"
checkmk_agent_version: "2.3.0p15"
checkmk_folder: "/linux/dls"
```

**Playbook Example**
Include the role in your playbook:


```yaml
- name: Install and configure Checkmk agent
  hosts: all
  become: true
  roles:
    - role: checkmk_agent
```

#### Dependencies
This role depends on the `checkmk.general` collection. Ensure it is installed before using this role:


```bash
ansible-galaxy collection install checkmk.general
```

#### Notes
Ensure the Checkmk agent installation files (`check-mk-agent_{{ checkmk_agent_version }}_all.deb and check-mk-agent_{{ checkmk_agent_version }}.noarch.rpm`) are present in the `files` directory of the role.


License
This project is licensed under the MIT License. See the LICENSE file for details.

