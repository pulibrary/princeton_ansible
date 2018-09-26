## MariaDB

Installs and configures a mariadb server

### Role variables

`db_version`: 10.3 # otherwise defaults to 10.2
`mariadb_mysql_root_password`: `saved in ansible-vault`

### Dependencies

None

### Example Playbook

This is a sample playbook file for deploying `pulibrary.mariadb` role to
`1.2.3.4`

```yaml
---
- hosts: mariadb
  remote_user: pulsys
  become: true
    - group_vars/site_vars.yml
    - group_vars/mariadb.yml
  roles:
    - role: pulibrary.mariadb
```

## TODO
* Automate creation of clusters
