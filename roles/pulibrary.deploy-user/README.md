Deploy User
===========

This role installs a system user on a remote target

Role Variables
--------------

- `generic_app_user` by default the role will install the user `deploy` unless you
use the `-e` flag to pass a different user

Example Playbook
----------------

To install a remote user run the following

```
ansible-playbook --limit 1.2.3.5 -e generic_app_user=aspace plum.yml -b
```

This will add the user aspace to the remote endpoint 1.2.3.5

License
-------

BSD
