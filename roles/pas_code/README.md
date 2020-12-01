Role Name
=========

A role to deploy the pas code and database to a machine

Requirements
------------

### Getting a new sql.zip for pas-code

On slavery-prod1 (get the password from the vault)
```
mysqldump -h mariadb-prod1.princeton.edu -p -u pas pas_prod > /tmp/pas.sql
```

On your machine
```
cd <princeton-ansible projectdir>/roles/pas_code/files
scp pulsys@slavery-prod1:/tmp/pas.sql .
zip pas.zip pas.sql
rm pas.sql
```


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

 pas     #installs the machine requirements for PAS

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables
passed in as parameters) is always nice for users too:

    - hosts: servers
      vars:
        - running_on_server: true # needed to force the docker samba items to run
      roles:
        - role: roles/pas
        - role: roles/pas_code
