Role Name
=========

This role installs MariaDB Server.

Requirements
------------

If you want to manage users use the pulibrary.mariadb role

Role Variables
--------------

Sane defaults but look in the defaults directory

Dependencies
------------

- pulibrary.common

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables
passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: roles/pulibrary.mariadbserver }

License
-------

MIT

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
