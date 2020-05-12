Role Name
=========

Installs percona db in a non-clustered environment

Requirements
------------

the root user uses unix socket connection to the db server 

Role Variables
--------------

If you want the DB to listen to more that localhost change `mysql_bind_address` in `defaults/main.yml`

Dependencies
------------


Example Playbook
----------------

Look inside the [molecule/default/playbook.yml](molecule/default/playbook.yml) for an example playbook


License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
