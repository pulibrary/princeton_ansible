Role Name
=========

Configures the permissions and paths of an SFTP servers

Requirements
------------

A Rocky Linux endpoint

Role Variables
--------------
```ini
sftp_user: "username"
allowed_ssh_users:
  - sftp_user
```

Dependencies
------------

the deploy_user role and the ad_join role

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: username.rolename, x: 42 }

License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a website (HTML is not allowed).
