Deploy User
===========

This role installs a system user on a remote target with a github key for checking out private repos on https://github.com/pulibrary.

Role Variables
--------------

- `generic_app_user` by default the role will install the user `deploy` unless you
use the `-e` flag to pass a different user

Example Playbook
----------------

```
- name: Converge
  hosts: all
  vars:
    - runnning_on_server: true
    - generic_app_user: 'aspace'
  roles:
    - role: pulibrary.deploy-user
  pre_tasks:
    # To allow the app user to access a specific private git repo you need to add an deploy key.
    # There is documentation on creating a deploy key and setting up github to use it here: https://developer.github.com/v3/guides/managing-deploy-keys/#deploy-keys
    # You must then give the contents of the key to this role.
    # I reccommed storing the key as a ansible-vault file and passing it to this role as shown below
    - set_fact:
        deploy_id_rsa_private_key: "{{  lookup('file', '../../files/id_rsa')  }}\n"
```

To install a remote user run the following

```
ansible-playbook --limit 1.2.3.5 -e generic_app_user=aspace figgy.yml -b
```

This will add the user aspace to the remote endpoint 1.2.3.5

License
-------

BSD
