Role Name
=========

Installs composer

Requirements
------------

None


Role Variables
--------------

```bash
composer_path: "/usr/local/bin"
composer_paths: []
md5_value: "242f22ee3380bb7960e9f4ba6ce4eb37"
```

Dependencies
------------

- pulibrary.common
- pulibrary.php

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables
passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: roles/pulibrary.composer }

License
-------

MIT

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
