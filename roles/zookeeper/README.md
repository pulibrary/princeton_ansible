# ZooKeeper Role

This Ansible role installs and configures Apache ZooKeeper for use with SolrCloud.

## Overview

The ZooKeeper role sets up an ensemble of ZooKeeper nodes to provide coordination services for SolrCloud. ZooKeeper is essential for managing the distributed state, configuration, and synchronization of SolrCloud nodes.

## Requirements

* Ansible 2.9+
* Ubuntu 18.04+ or Debian-based system
* Proper firewall rules to allow ZooKeeper communication (ports 2181, 2888, 3888)

## Role Variables

All variables are defined in `defaults/main.yml` and can be overridden:

```
yaml
# User and group that will own the ZooKeeper installation
zk_user: "zookeeper"
zk_group: "zookeeper"

# ZooKeeper directories
zk_data_dir: "/var/lib/zookeeper/data"
zk_log_dir: "/var/lib/zookeeper/log"

# ZooKeeper ports
zk_client_port: 2181     # Client connection port
zk_leader_port: 2888     # Leader election: followers connect to leaders
zk_election_port: 3888   # Leader election: voting

# ZooKeeper ensemble configuration
# Define the nodes in your ZooKeeper ensemble
zk_nodes:
  - { id: 1, host: "sandbox-zk1.lib.princeton.edu" }
  - { id: 2, host: "sandbox-zk2.lib.princeton.edu" }
  - { id: 3, host: "sandbox-zk3.lib.princeton.edu" }

# Set to true on actual servers, false for local testing
running_on_server: true
```

## Dependencies

None.

## Example Playbook

```
yaml
---
- name: Set up ZooKeeper ensemble
  hosts: zookeeper_servers
  become: true
  
  roles:
    - zookeeper
```

## Example Inventory

```
yaml
---
all:
  children:
    zookeeper_servers:
      hosts:
        sandbox-zk1.lib.princeton.edu:
          zk_id: 1
        sandbox-zk2.lib.princeton.edu:
          zk_id: 2
        sandbox-zk3.lib.princeton.edu:
          zk_id: 3
```

## Files and Templates

* `templates/zoo.cfg.j2` - Main ZooKeeper configuration
* `templates/zookeeper.service.j2` - Systemd service file

## License

MIT

## Author Information

Princeton University Library
