# SolrCloud Ansible Role

This Ansible role installs and configures Apache Solr in cloud mode (SolrCloud), supporting both Solr 8.x and Solr 9.x versions. It uses a direct file installation approach for better reliability and control.

## Features

* Direct file installation of SolrCloud (no reliance on install script)
* Solr 9.x versions (it can install a greenfield solr8)
* ZooKeeper integration for cloud mode
* Consistent directory structure and paths
* Comprehensive logging configuration
* Performance tuning with proper JVM settings
* Modern systemd service management
* Security configuration options

## Requirements

* Ansible 2.9 or higher
* Debian/Ubuntu-based target systems
* Java 17+ installed on target servers
* ZooKeeper ensemble configured and running

## Role Variables

All variables are defined in `defaults/main.yml` with sensible defaults. Here are the key variables you may want to customize:

### Version Settings

```
yaml
solr_cloud_download_version: "9.2.0"  # Solr version to install
solr_cloud_url: "https://mirror-server/solr/{{ solr_cloud_download_version }}/{{ solr_cloud_package }}"
```

### User and Directories

```
yaml
solr_user: deploy
solr_group: deploy

solr_home: /solr
solr_data_dir: "{{ solr_home }}/data"
solr_log_dir: "{{ solr_home }}/logs"

solr_installation: "/opt/solr"  # Symlink to versioned directory
solr_versioned_dir: "/opt/solr-{{ solr_cloud_download_version }}"
```

### JVM Settings

```
yaml
solr_heap: "20g"  # JVM heap size
```

### ZooKeeper Configuration

```
yaml
solr_zookeeper_hosts:
  - "zk1.example.com:2181"
  - "zk2.example.com:2181"
  - "zk3.example.com:2181"
solr_znode: "solr9"  # or "solr8" for Solr 8.x
```

## System Properties

This role sets the following critical system properties for Solr:

```
-Dsolr.solr.home=/solr
-Dsolr.solr.home=/solr/data
-Dsolr.log.dir=/solr/logs
-Dsolr.install.symDir=/opt/solr
-Dsolr.allowPaths=/solr/data
-Dlog4j.configurationFile=/solr/log4j2.xml
-Dsolr.jetty.host=0.0.0.0
-Djetty.home=/opt/solr/server
```

## Directory Structure

The role creates the following directory structure for a clean, maintainable installation:

```
/opt/solr -> /opt/solr-9.2.0     # Symlink to the versioned directory
/opt/solr-9.2.0/                 # Versioned installation
/solr/                           # Solr home
/solr/data/                      # Solr data directory
/solr/data/backup                # Solr backup directory
/solr/logs/                      # Solr logs
/run/solr/                       # PID directory (modern systemd location)
```

## Example Playbook

```
yaml
---
- hosts: solr_servers
  become: true
  roles:
    - role: solrcloud
      vars:
        solr_cloud_download_version: "9.2.0"
        solr_heap: "32g"
        solr_zookeeper_hosts:
          - "zk1.example.com:2181"
          - "zk2.example.com:2181"
          - "zk3.example.com:2181"
```

## Troubleshooting

### Common Issues

1. **Service Fails to Start**: Check logs in `/solr/logs/solr-8983-console.log`
2. **Entropy Issues**: The role adds `-Djava.security.egd=file:/dev/./urandom` to fix low entropy issues
3. **ZooKeeper Connection**: Verify ZooKeeper connectivity from Solr nodes

### Manual Testing

You can manually start Solr with debugging enabled:

```
bash
sudo -u deploy /opt/solr/bin/solr start -f -v
```

## License

MIT

## Author Information

Maintained by Princeton University Library
