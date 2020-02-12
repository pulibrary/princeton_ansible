Role Name
=========

Installs PostgreSQL on an endpoint

Requirements
------------


Role Variables
--------------

Variables are in `defaults/main.yml` and `vars/main.yml` on the `defaults/main.yml` we can change what version of PostgreSQL you want installed. Under `molecule/defaults/playbook.yml` look at the variables. If you have those variables on your playbook the role will "do the right thing" It will add a new database and modify the `pg_hba.conf` file and reload the database server


Dependencies
------------

We depend on `pulibrary.common`

Example Playbook
----------------

There is an example under `molecule/defaults/playbook.yml`

License
-------

MIT

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
