Role Name
=========

Configures an endpoint as a sendmail relay

Requirements
------------


Role Variables
--------------

The role will be used as part of another role. It will take the ip address of the inventory endpoint and add it to the allow list

add `sendmail_is_local: false` to you `group_vars/<your_project>`

Dependencies
------------

It should be run as part of another role

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
