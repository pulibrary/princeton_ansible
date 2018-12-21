Role Name
=========

This role installs Open Journal Systems on Ubuntu

Requirements
------------

Find them in the playbook example

Role Variables
--------------

```
apache:
  docroot: "/var/www/ojs"
  servername: "{{ ansible_hostname }}"

server:
  timezone: "America/New_York"

ojs_file_uploads: "/var/local/files"
ojs_home: "/var/www/ojs-{{ ojs_version }}"
ojs_db_password: "vault_ojs_db_password"
application_dbuser_name: "ojs"
application_db_name: "ojs"
application_dbuser_password: "ojs_db_password"
application_dbuser_role_attr_flags: "SUPERUSER,INHERIT,NOCREATEDB,NOCREATEROLE,NOREPLICATION"
postgres_version: "10"
```

Example Playbook
----------------

```
    - hosts: ojs
      remote_user: pulsys
      become: true
      vars_files:
        - ../site_vars.yml
        - group_vars/ojs/main.yml
        - group_vars/ojs/vault.yml

      roles:
        - role: roles/pulibrary.common
        - role: roles/pulibrary.deploy-user
        - role: roles/pulibrary.postgresql
        - role: roles/pulibrary.php
        - role: roles/pulibrary.composer
        - role: roles/pulibrary.nodejs
        - role: roles/pulibrary.ojs
```

License
-------

MIT
