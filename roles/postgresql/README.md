Role Name
=========

Allows you to connect to a postgres database server and create a single user and database.

Requirements
------------

none

Role Variables
--------------

### Connection information to the database server: 
```ini
  postgres_host - postgres server
  postgres_port - defaults to postgres default port
  postgres_admin_user - defaults to none
  postgres_admin_password - defaults to none
  postgresql_is_local - should always be false unless testing
```

### Connection information for the database you want to create or connect to
```ini
  application_dbuser_name
  application_dbuser_password
  application_db_name
  application_dbuser_role_attr_flags - for example "CREATEDB"
```
    
Dependencies
------------

none

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables
passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: postgresql, x: 42 }

License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
