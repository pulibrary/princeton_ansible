MariaDB (MySQL) role
=========

This role installs and manages connections to mariadb. The role supports different modes of operation depending on the presence of MariaDB installed locally or not

Requirements
------------


Role Variables
--------------


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

If installing a new mariadb server

```bash
mysql_server: true
```

Dependencies
------------

A list of other roles hosted on Galaxy should go here, plus any details in regards to parameters that may need to be set for other roles, or variables that are used from other roles.

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: username.rolename, x: 42 }

License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a website (HTML is not allowed).
