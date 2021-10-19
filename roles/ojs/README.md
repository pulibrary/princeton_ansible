Role Name
=========

This role installs Open Journal Systems on Ubuntu

Requirements
------------

None

Role Variables
--------------

```bash
ojs_version: "3.3.0-8"
ojs_file_uploads: "/var/local/files"
ojs_home: "/var/www/ojs-{{ ojs_version }}"
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
        - role: roles/common
        - role: roles/deploy_user
        - role: roles/postgresql
        - role: roles/php
        - role: roles/composer
        - role: roles/nodejs
        - role: roles/ojs
```

License
-------

MIT

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
