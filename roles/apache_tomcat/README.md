Role Name
=========

Installs Tomcat via "wget" instead of package

Requirements
------------

Expects openjdk (version 1.8)

Role Variables
--------------

The key variable is

`tomcat_version:` (which is the tomcat version to install)

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables
passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: roles/apache_tomcat, x: 42 }

License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
