Role Name
=========

This installs and configures Graylog log management

Requirements
------------


Role Variables
--------------

The role variables are under the `default` directory

Dependencies
------------

`pulibrary.elastic`

Example Playbook
----------------

    - hosts: graylog
      vars:
      cluster.name: graylog
      es_heap_size: "1g"
      roles:
         - { role: roles/pulibrary.graylog}

License
-------

MIT

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
