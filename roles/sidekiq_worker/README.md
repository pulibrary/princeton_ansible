Role Name
=========

This role installs sidekiq_workers

Requirements
------------

This role expects the `rails_app`

Role Variables
--------------

Variables in `defaults/main.yml`, including:

| Variable | Default | Description |
|----------|---------|-------------|
| `sidekiq_worker_name` | `sidekiq-workers` | systemd unit name |
| `sidekiq_worker_threads` | `5` | Sidekiq concurrency (`-c`) |
| `sidekiq_worker_queues` | high, mailers, default, low, super_low | Queues |
| `sidekiq_worker_limit_nofile` | `65536` | systemd `LimitNOFILE` for the worker unit |

Dependencies
------------


Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - {role: username.rolename}

License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a website (HTML is not allowed).
