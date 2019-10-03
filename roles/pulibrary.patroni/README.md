Role Name
=========

This installs a Patroni Template PostgreSQL cluster

Requirements
------------


Role Variables
--------------

In the `group_vars/patroni/postsgres< staging | prod >.yml` add the user you'd like to have access to the cluster

Dependencies
------------


Example Playbook
----------------

    - hosts: servers
      roles:
         - { role: roles/pulibrary.patroni }

License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
