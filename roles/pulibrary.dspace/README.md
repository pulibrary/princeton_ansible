pulibrary.dspace
=========

This role installs all the prerequisite software to install dspace. It is
unlikely to be used as a standalone role. The configuration will often be in a
separate role that configures it.

Requirements
------------

Look in the `meta/main.yml` file

Role Variables
--------------

```
dspace_version: 6.3
```

Dependencies
------------

The dependencies for this role are under `meta/main.yml`

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables
passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: roles/pulibrary.dspace }

License
-------

MIT
