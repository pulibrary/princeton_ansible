MariaDB (MySQL) role
=========

This role installs and manages connections to mariadb. The role supports different modes of operation depending on the presence of MariaDB installed locally or not

Requirements
------------


Role Variables
--------------

Most use cases will have the variables below and only the mysql-common client
will be installed

```bash
mysql_server: false

mysql_host: "some.remotedb.edu"

mysql_root_password: "{{ vault_maria_mysql_root_password }}"
mysql_databases:
  - name: "some_database"
    encoding: utf8mb4
    collation: utf8mb4_general_ci

mysql_users:
  - name: "some_user"
    host: "%"
    password: "change_me"
    priv: "some_database.*:ALL"
```

If installing a brand new mariadb server the `mysql_server` will be set to true
which means mariadb server will be installed

If installing a new mariadb server

```bash
mysql_server: true
```
