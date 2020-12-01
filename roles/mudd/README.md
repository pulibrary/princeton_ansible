Role Name
=========

A role to bring up the Mudd machines

Requirements
------------

none

Role Variables
--------------

This role contains no additional variables beyond the rails-app

Dependencies
------------

rails-app
  rails_app_name: 
  rails_app_directory:
  rails_app_env: 
postgresql
  postgres_host: 
  postgres_version:
  application_db_name: 
  application_dbuser_name: 
  application_dbuser_password:
  application_dbuser_role_attr_flags: 
  application_host_protocol:
passenger
  passenger_server_name:
  passenger_app_root:
  passenger_app_env:
  passenger_ruby:

Example Playbook
----------------

    - hosts: servers
      roles:
         - { role: roles/pulibrary.mudd, rails_app_name: 'example' }
