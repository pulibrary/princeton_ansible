# Ansible Role: SolrCloud

This Ansible role installs and configures Apache Solr in SolrCloud mode with parametric support for both Solr 8.4.0 and 9.2.0 on Ubuntu Jammy (22.04).

## Requirements

* Ubuntu Jammy (22.04)
* Ansible 2.9 or higher
* Working ZooKeeper ensemble (see companion zookeeper role)
* Minimum of Java 11 for Solr 8.4.0
* Minimum of Java 17 for Solr 9.2.0 (installed automatically by the role)

## Role Variables

Available variables are listed below, along with default values (see `defaults/main.yml`):

```
yaml
# Solr version - can be "8.4.0" or "9.2.0"
solr_version: "8.4.0"

# System user and group
solr_user: "deploy"
solr_group: "deploy"

# Directory configurations
solr_home: "/solr"
solr_data_dir: "/solr/data"
solr_port: 8983

# ZooKeeper configuration
zookeeper_hosts:
  - "lib-zk1.example.edu:2181"
  - "lib-zk2.example.edu:2181"
  - "lib-zk3.example.edu:2181"

# Solr nodes
solr_nodes:
  - "lib-solr1.example.edu"
  - "lib-solr2.example.edu"
  - "lib-solr3.example.edu"
```

## Example Playbook

```
yaml
---
- hosts: solr_nodes
  vars:
    solr_version: "9.2.0"  # For Solr 9
  roles:
    - solrcloud
```

## Example Inventory

```
ini
[solr_nodes]
lib-solr1.example.edu
lib-solr2.example.edu
lib-solr3.example.edu
```

## Configuration Details

The role will:

1. Install appropriate Java version based on Solr version

   * OpenJDK 11 for Solr 8.4.0
   * OpenJDK 17 for Solr 9.2.0

2. Create necessary user and group

3. Configure directories with proper permissions

4. Download and install specified Solr version

5. Configure SolrCloud with ZooKeeper ensemble integration

6. Deploy version-specific solr.xml configuration

7. Set up systemd service

8. Configure Solr to listen on all interfaces

## Generated Configurations

### Directory Structure

```
Copy
/solr/
├── data/
│   └── solr.xml  # Version-specific configuration
/opt/solr/
└── bin/
    └── solr.in.sh  # Main Solr configuration
```

### Service Configuration

* Systemd service file: `/etc/systemd/system/solr.service`
* Service runs as: `deploy` user
* Automatic startup: Enabled
* Network: Listens on all interfaces (0.0.0.0)

## Important Paths

* Home directory: `/solr`
* Data directory: `/solr/data`
* Installation directory: `/opt/solr`
* PID directory: `/var/run/solr`
* Log directory: `/var/log/solr`

## Dependencies

* Requires a working ZooKeeper ensemble (see companion [zookeeper role](./roles/zookeeper))
* Java dependencies are handled by the group_vars

## Version-Specific Features

### Solr 8.4.0

* Uses OpenJDK 11
* Basic solr.xml configuration

### Solr 9.2.0

* Uses OpenJDK 17

* Enhanced solr.xml configuration with additional features:

  * shareSchema
  * configSetBaseDir
  * coreRootDirectory
  * allowPaths

## Networking

* SolrCloud is configured to listen on all interfaces (0.0.0.0)
* Default port: 8983
* Requires connectivity to ZooKeeper ensemble on port 2181

## License

MIT
