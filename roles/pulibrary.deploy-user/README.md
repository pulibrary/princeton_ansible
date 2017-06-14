Deploy User
===========

This role installs a system user on a remote target


Example Playbook
----------------

To install a remote user run the following

```
ansible-playbook --limit 1.2.3.5 -e system_user=deploy plum.yml -b
```

License
-------

BSD
