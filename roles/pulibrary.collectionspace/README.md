Role Name
=========

This role installs CollectionSpace on Ubuntu Xenial

Requirements
------------

    - role: roles/pulibrary.common
    - role: roles/pulibrary.deploy-user
    - role: roles/pulibrary.openjdk8
    - role: roles/pulibrary.postgresql
    - role: roles/pulibrary.apache2

Role Variables
--------------

```
postgres_host: 'remote_or_localhost',
project_db_host: '127.0.0.1',
db_host: "localhost",
postgres_admin_user: 'postgres',
postgres_admin_password: nil,
deploy_user: "cspace"
application_db_name: "cspace_db"
application_dbuser_name: "csadmin"
application_dbuser_password: "csadmin_db_admin_password"
application_dbuser_role_attr_flags: "SUPERUSER,INHERIT,NOCREATEDB,NOCREATEROLE,NOREPLICATION"
postgres_version: "10"
cspace_instance_id: "{{ instance_name | default('_staging') }}"
csadmin_db_admin_password: "vault_csadmin_db_admin_password"
db_nuxeo_password: "vault_db_nuxeo_password"
db_cspace_password: "vault_db_cspace_password"
db_reader_password: "vault_db_reader_password"
cspace_version: "5.0"
apache:
  docroot: "/var/www/html"
  servername: "{{ ansible_hostname }}"

```

Example Playbook
----------------

    - hosts: collectionspace
      remote_user: pulsys
      become: true
      vars_files:
        - ../site_vars.yml
        - group_vars/collectionspace/main.yml
        - group_vars/collectionspace/vault.yml

      roles:
        - role: roles/pulibrary.common
        - role: roles/pulibrary.deploy-user
        - role: roles/pulibrary.openjdk8
        - role: roles/pulibrary.postgresql
        - role: roles/pulibrary.apache2
        - role: roles/pulibrary.collectionspace


License
-------

MIT
