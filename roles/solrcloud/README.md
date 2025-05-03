# SolrCloud Role

This Ansible role installs and configures Apache Solr in cloud mode (SolrCloud).

## Overview

The SolrCloud role sets up a distributed Solr installation that leverages ZooKeeper for configuration management, failover, and high availability. This role supports multiple versions of Solr and configures it to work with an existing ZooKeeper ensemble.

## Requirements

* Ansible 2.9+
* Ubuntu 18.04+ or Debian-based system
* Java 11 or 17 (will be installed as a dependency)
* A running ZooKeeper ensemble
* Proper firewall rules to allow Solr communication (port 8983)

## Role Variables

All variables are defined in `defaults/main.yml` and can be overridden:

```
yaml
# User and group that will own the Solr installation
solr_user: "deploy"
solr_group: "deploy"

# Solr directories
solr_data_dir: "/solr/data"
solr_data_home: "/solr"
solr_log_dir: "/solr/logs"
solr_installation: "/opt/solr/solr-{{ solr_version }}"
solr_bin: "{{ solr_installation }}/bin/solr"

# Set to true on actual servers, false for molecule testing
running_on_server: true

# Version settings - can be overridden in playbook
solr_version: "8.6.0"  # Can be overridden to "9.2.0" or other versions
solr_cloud_download_version: "{{ solr_version }}"
solr_cloud_build_name: "solr-{{ solr_cloud_download_version }}"
solr_cloud_package: "{{ solr_cloud_build_name }}.tgz"
solr_cloud_url: "https://pulmirror.princeton.edu/mirror/solr/dist/lucene/solr/{{ solr_cloud_download_version }}/{{ solr_cloud_package }}"

# ZooKeeper ensemble configuration
solr_zookeeper_hosts:
  - "sandbox-zk1.lib.princeton.edu:2181"
  - "sandbox-zk2.lib.princeton.edu:2181"
  - "sandbox-zk3.lib.princeton.edu:2181"
solr_zookeeper_hosts_string: "{{ solr_zookeeper_hosts | join(',') }}"
solr_znode: "/solr"

# Service configuration
solr_service_state: "started"
solr_service_enabled: true

# Java settings
solr_java_mem: "-Xms2g -Xmx4g"
solr_gc_tune: "-XX:+UseG1GC -XX:+PerfDisableSharedMem -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=250 -XX:+AlwaysPreTouch"

# JAR directories
jardirectory: "/opt/solr/server/solr-webapp/webapp/WEB-INF/lib"
webapp_jardirectory: "/opt/solr/server/solr-webapp/webapp/WEB-INF/lib"
```

## Dependencies

None, but requires a running ZooKeeper ensemble that Solr can connect to.

## Example Playbooks

### Basic playbook with default values

```
yaml
---
- name: Set up SolrCloud
  hosts: solr_servers
  become: true
  
  roles:
    - solrcloud
```

### Installing Solr 8.6.0

```
yaml
---
- name: Install Solr 8.6.0
  hosts: solr_servers
  become: true
  
  vars:
    solr_version: "8.6.0"
  
  roles:
    - solrcloud
```

### Installing Solr 9.2.0

```
yaml
---
- name: Install Solr 9.2.0
  hosts: solr_servers
  become: true
  
  vars:
    solr_version: "9.2.0"
  
  roles:
    - solrcloud
```

## Example Inventory

```
yaml
---
all:
  children:
    solr_servers:
      hosts:
        sandbox-solr1.princeton.edu:
          solr_node_id: 1
        sandbox-solr2.princeton.edu:
          solr_node_id: 2
        sandbox-solr3.princeton.edu:
          solr_node_id: 3
      vars:
        solr_zookeeper_hosts:
          - sandbox-zk1.lib.princeton.edu:2181
          - sandbox-zk2.lib.princeton.edu:2181
          - sandbox-zk3.lib.princeton.edu:2181
```

## Version-Specific Features

### Solr 8.x

* Standard configuration using solr.xml
* Supports scripting plugins with Nashorn engine
* Log4j configurations for version-specific logging

### Solr 9.x

* Enhanced security with BasicAuthPlugin
* Java 17 compatibility settings
* Additional Java options for modern JVMs
* Security configuration uploaded to ZooKeeper automatically

## Files and Templates

* `templates/solr.service.j2` - Systemd service file
* `templates/solr.in.sh.j2` - Environment variables for Solr
* `templates/solr.xml.j2` - Solr core configuration
* `templates/solr.conf.j2` - System limits configuration
* `templates/log4j.properties.j2` - Logging for older Solr versions
* `templates/log4j2.xml.j2` - XML-based logging for newer versions
* `templates/security.json.j2` - Security configuration for Solr 9.x

## Backup Configuration

The role also configures backups to network shares:

* Mounts network shares using CIFS
* Configures credentials for secure authentication
* Sets up backup directories with proper permissions

## Upgrading Between Versions

To upgrade an existing Solr installation:

1. Update the `solr_version` variable to the new version
2. Run the playbook with `--tags=install,configure`
3. Verify the new version is working correctly
4. If needed, reindex your data to take advantage of new features

## License

MIT

## Author Information

Princeton University Library
