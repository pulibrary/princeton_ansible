Role Name
=========

Manages a Subversion Server

Requirements
------------

An already configured subversion server

Role Variables
--------------

* in `vars/main.yml` # the name of the subversion user
* in `defaults/main.yml` # the user harry and sally are examples

Create a new vaulted user and saved the username and password under `group_vars/lib-svn/vault.yml`


Dependencies
------------

This role depends on `pulibrary.svn` and `pulibrary.deploy-user`

Example Playbook
----------------

    - hosts: servers
      roles:
         - { role: roles/pulibrary.lib-svn }

License
-------

MIT

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
