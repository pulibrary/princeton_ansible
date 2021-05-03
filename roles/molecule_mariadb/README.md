Role Name
=========

A role that installs mariadb for molecule testing only.  **Not intended for server use!!**

Requirements
------------

None

Role Variables
--------------

mysql_root_password:  the password the tested role is expecting for mariadb

Dependencies
------------

* apt
* service
* mysql_user

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: molecule_maraidb, mysql_root_password: 'changeme' }

License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a website (HTML is not allowed).
