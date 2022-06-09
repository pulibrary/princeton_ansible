Role Name
=========

Configures an endpoint to use [SSSD](https://ubuntu.com/server/docs/service-sssd) to connect to Princeton Active Directory

Requirements
------------

One will need access to [OIT AD Machine Registration Tool](https://tools.princeton.edu/Dept/) This allows you to register a new name for AD


Role Variables
--------------


Dependencies
------------

- [roles/common](roles/common)

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
