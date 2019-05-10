Role Name
=========

A role to generate the machine for running Princeton and Slavery (PAS) site

Requirements
------------

Any pre-requisites that may not be covered by Ansible itself or the role should
be mentioned here. For instance, if the role uses the EC2 module, it may be a
good idea to mention in this section that the boto package is required.

Role Variables
--------------
  apache_app_path: '/opt/pas/web'
  pas_db_user: 'pas'
  pas_db_name: 'pas'
  pas_file_directory: 'uploads'
  pas_db_password: '{{ pas_password }}'
  pas_server_name: '{{ application_server | default("localhost") }}'
  pas_site_url: '{{ application_site_url | default("http://localhost:8484") }}'
  pas_base_url: '{{ application_base_url | default("http://localhost:8484") }}'
  db_port: 3306
  apache2:
     directory_options: '+Multiviews'

Dependencies
------------
  apache2
  php
  mariadbserver
  mariadb
  deploy-user
  nodejs
  samba

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables
passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: roles/pulibrary.pas, x: 42 }
