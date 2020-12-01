Role Name
=========

Installs composer

Requirements
------------

You will want to download a current version of [composer](https://getcomposer.org/download/). Place the file under [local_files/composer](local_files/composer)

Role Variables
--------------

```yaml
composer_path: "/usr/local/bin"
composer_paths: []
composer_checksum: 'sha384:a5c698ffe4b8e849a443b120cd5ba38043260d5c4023dbf93e1558871f1f07f58274fc6f4c93bcfd858c6bd0775cd8d1'
```

Dependencies
------------

- common
- php

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables
passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: roles/composer }

License
-------

MIT

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
