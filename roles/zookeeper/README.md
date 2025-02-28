# Zookeeper

This Ansible role installs and configures Apache ZooKeeper in an ensemble/cluster configuration on Ubuntu Jammy (22.04).

## Requirements

Ubuntu Jammy (22.04)
Ansible 2.9 or higher
Three hosts for ZooKeeper ensemble

## Role Variables

Available variables are listed below, along with default values (see [defaults/main.yml](defaults/main.yml)):

```yaml
# ZooKeeper system user and group
zk_user: "zookeeper"
zk_group: "zookeeper"

# Directory configurations
zk_data_dir: "/var/lib/zookeeper"
zk_log_dir: "/var/log/zookeeper"

# Port configurations
zk_client_port: 2181
zk_leader_port: 2888
zk_election_port: 3888

# ZooKeeper nodes configuration
zk_nodes:
  - id: 1
    host: "lib-zk1.example.edu"
  - id: 2
    host: "lib-zk2.example.edu"
  - id: 3
    host: "lib-zk3.example.edu"
```

______________________________________________________________________

## Example Playbook

```
- hosts: servers
  roles:
     - { role: zookeeper }
```

### Example Inventory

```yaml
[zookeeper_nodes]
```

### Configuration Details

The role will:

1. Install Zookeeper from Ubuntu's package repository
1. Configure the Zookeeper ensemble with the specified nodes
1. Set up proper node IDs in `/var/lib/zookeeper/myid`
1. Configure Zookeeper with the provided ports for client connections, leader election, and quorum communication

### Generated Configuration

The role will generate configuration at `/etc/zookeeper/conf/zoo.cfg` with the following structure

```yaml
tickTime=2000
initLimit=10
syncLimit=5
dataDir=/var/lib/zookeeper
dataLogDir=/var/log/zookeeper
clientPort=2181
# List of servers
server.1=lib-zk1.example.edu:2888:3888
server.2=lib-zk2.example.edu:2888:3888
server.3=lib-zk3.example.edu:2888:3888
# Set higher timeout for leader election
electionAlg=3
maxSessionTimeout=60000
```

### File locations

Important files and directories:

- Configuration file: `/etc/zookeeper/conf/zoo.cfg`
- Node ID file `/var/lib/zookeeper/myid`
- Data Directory `/var/lib/zookeeper`
- Log Directory `/var/log/zookeeper`
