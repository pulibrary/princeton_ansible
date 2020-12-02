Role Name
=========

This role installs [figgy](https://github.com/pulibrary/figgy) a Valkyrie based digital repository application

Requirements
------------

Figgy will need a [postgresql](../psql/) database, a [sidekiq](../sidekiq) worker, a [filewatcher](../filewatcher) worker, a [pubsub](../figgy_pubsub_worker) worker.
In addition figgy will need [memcached](../memcached) and [rabbitmq](../rabbitmq)

Role Variables
--------------

the variables are defined in [defaults/main.yml](defaults/main.yml)

```yaml
app_db_name: 'figgy'
app_db_user: 'figgy'
app_db_password: 'figgy'
app_db_host: 'localhost'
app_host_name: 'localhost'
```

Dependencies
------------

All the depenencies are found under [meta/main.yml](meta/main.yml)

Example Playbook
----------------

The playbook has to sets of hosts. One for figgy and the figgy workers listed in Requirements above

```yaml
- hosts: figgy
  remote_user: pulsys
  roles:
    - role: roles/figgy
- hosts: figgy_worker
  remote_user: pulsys
  roles:
    - role: roles/memcached
    - role: roles/rabbitmq
    - role: roles/figgy
```

License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
