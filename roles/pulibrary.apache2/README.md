## Apache Webserver

Installs and configures Apache2

Generally this role is dependency of another

### Role variables


This role has multiple variables. The defaults for all these variables are the following:

```yaml
---
apache:
  docroot: '/var/www/html'
  servername: 'libserv
```

### Dependencies

None

### Example Playbook

This is a sample playbook file for deploying the `pulibrary.apache2` role in a localhost

```yaml
---
- hosts: localhost
  become: true
  roles:
    - role: pulibrary.apache2
  vars:
    apache.servername: localhost
```
