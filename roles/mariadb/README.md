Role Name
=========

This role installs and manages connections to mariadb. The role supports
different modes of operation depending on the presence of MariaDB installed
locally or not

Requirements
------------


Role Variables
--------------

```bash
mariadb__server: "some.remotedb.edu"

mariadb__databases:
  - name: "some_database"
    encoding: utf8mb4
    collation: utf8mb4_general_ci

mariadb__users:
  - name: "some_user"
    host: "%"
    password: "change_me"
    priv: "some_database.*:ALL"
```

Dependencies
------------

- pulibrary.common

Example Playbook
----------------

```bash
- hosts: servers
  roles:
     - { role: roles/pulibrary.mariadb}
```

License
-------

MIT
