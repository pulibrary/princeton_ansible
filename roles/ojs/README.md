Role Name
=========

This role installs Open Journal Systems on Ubuntu

Requirements
------------

None

Role Variables
--------------

```bash
ojs_version: "3_1_1-4"
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

Dependencies
------------


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

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
