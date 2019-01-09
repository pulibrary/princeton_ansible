Role Name
=========

This role installs Apache on Ubuntu

Requirements
------------

None

Role Variables
--------------

```
apache:
  docroot: "/var/www/html"

```

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables
passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: pulibrary.apache2, x: 42 }

License
-------

MIT

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
