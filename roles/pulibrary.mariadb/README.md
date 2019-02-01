Role Name
=========

This role installs and manages connections to mariadb. The role supports
different modes of operation depending on the presence of MariaDB installed
locally or not

Requirements
------------


Role Variables
--------------

```bash
mariadb__server: "some.remotedb.edu"
```

Dependencies
------------

- pulibrary.common

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables
passed in as parameters) is always nice for users too:


```bash
- hosts: servers
  roles:
     - { role: roles/pulibrary.mariadb}
```

License
-------

MIT

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
