Role Name
=========

A role to deploy the pas code and database to a machine

Requirements
------------

None

Role Variables
--------------

# set to true to force the code to be redeployed even if it already exists
force_pas_sql_import 'false'
# set to true to force a database import even if it has already been created
force_pas_deploy: 'false'
pas_db_user: 'pas'
pas_db_name: 'pas'
pas_file_directory: 'uploads'
pas_db_password: '{{ pas_password | default("change_this")}}'
pas_db_driver: 'mysql'
pas_db_schema: 'public'
pas_db_table_prefix: 'craft_'
pas_security_key: 'abc123'
pas_server_name: '{{ application_server | default("localhost") }}'
pas_default_site_url: 'https://localhost:8484'
pas_site_url: '{{ application_site_url | default("http://localhost:8484") }}'
pas_base_url: '{{ application_base_url | default("http://localhost:8484") }}'
pas_upload_path: 'pas/pas-staging'

Dependencies
------------

 pulibrary.pas     #installs the machine requirements for PAS

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables
passed in as parameters) is always nice for users too:

    - hosts: servers
      vars:
        - runnning_on_server: true # needed to force the docker samba items to run
      roles:
        - role: roles/pulibrary.pas
        - role: roles/pulibrary.pas_code
