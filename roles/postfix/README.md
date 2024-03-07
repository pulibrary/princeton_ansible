Role Name
=========

Installs postfix as a relay MTA. We use this role for our mail transfer agent. It is configured to relay messages to the university's SMTP server.
It sets up an allow list for our vms

Requirements
------------


Role Variables
--------------


Dependencies
------------


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
