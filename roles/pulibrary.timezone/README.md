Role Name
=========

sets an endpoints timezone

Requirements
------------


Role Variables
--------------

In the [default/main.yml](default/main.yml) (add a different timezone in your vars)

Dependencies
------------


Example Playbook
----------------


    - hosts: servers
      roles:
	  vars:
	    timezone: America/New_York
         - { role: roles/pulibrary.timezone }

License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
