Role Name
=========

This role installs Vireo, a system for submitting Electronic Theses and Dissertations (ETDs). Vireo is a java based open source application built by the Texas Digital Library. More information about the software is available at https://www.tdl.org/etds/.

Requirements
------------
* Requires Tomcat8

Role Variables
--------------
Variables can be found in `defaults/main.yml`

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables
passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: roles/tomcat8 }
         - { role: roles/vireo }

License
-------

BSD
