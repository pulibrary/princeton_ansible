Role Name
=========

This role installs Apache Tomcat8

Role Variables
--------------

Variables can be found in `defaults/main.yml`


Dependencies
------------

This role depends on `openjdk`


Example Playbook
----------------


    - hosts: servers
      roles:
         - { role: roles/tomcat8 }

