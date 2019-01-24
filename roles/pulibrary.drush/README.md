Role Name
=========

Installs Drush

Requirements
------------


Role Variables
--------------

```bash
drush_version: 8.*
drush_path: "/usr/local/bin"
```

Dependencies
------------

- pulibrary.composer
- pulibrary.common
- pulibrary.php

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables
passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: roles/pulibrary.drush }

License
-------

MIT

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
