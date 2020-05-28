Role Name
=========

Installs upstream's [nginx](https://www.nginx.com/resources/wiki/start/topics/tutorials/install/#ubuntu-ppa)
This role will always be a dependency of another

Requirements
------------


Role Variables
--------------


Dependencies
------------


Example Playbook
----------------

    - hosts: servers
      roles:
         - { role: roles/pulibrary.nginx, x: 42 }

License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
