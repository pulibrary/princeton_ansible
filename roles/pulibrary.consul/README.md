Role Name
=========

This role installs [Consul](https://consul.io/) on a remote endpoint. It is rare
and not recommended that you will ever need to install it as a standalone
install. (It expects 3 or 5 nodes)

Requirements
------------

Note that for the "local" installation mode (the default), the role will locally
download only one instance of consul, archive, unzip it and install the
resulting binary on all the consul hosts

Role Variables
--------------

The role uses variables define in `defaults/main.yml`

Dependencies
------------

Ansible requires GNU tar and this role performs some local use of the unarchive
module, so `gtar` needs to be in your PATH. macOS will occasionally spit out odd
errors during unarchive tasks if you don't have `gtar`

Example Playbook
----------------

```
ansible-playbook playbooks/consul.yml
```

License
-------

MIT

TODO

* enable DNSmasq
