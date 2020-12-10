Role Name
=========

A role to run jobs related to library-wide systems processes.

Role Variables
--------------

vault_sfx_host
vault_sfx_port
vault_sfx_user
vault_sfx_pass
vault_sfx_global
vault_sfx_local
vault_wc_key: Worldcat API key

Dependencies
------------

ruby
deploy_user
mariadb

Example Playbook
----------------

    - hosts: servers
      roles:
         - { role: roles/lib_jobs }

License
-------

BSD

