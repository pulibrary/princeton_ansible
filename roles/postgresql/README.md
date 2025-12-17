Role Name
=========

Allows you to connect to a postgres database server and create a single user and database.

Requirements
------------

none

Role Variables
--------------

### Server-side variables

These vars provide connection information to the database server. By convention we store these values in `/group_vars/postgresql/<env>.yml`.

```ini
  postgresadmin: "postgres"
  db_clusteradmin_user: "postgres"
  db_clusteradmin_password: "{{ vault_postgres_admin_password }}"
  postgres_admin_password: '{{ vault_postgres_admin_password }}'
  postgres_port: 5432
  postgres_admin_user: "{{ postgresadmin }}"
  postgresql_is_local: true  # rarely true unless one is testing creating a new db server
  postgres_version: 15  # on server side this will install the postgresql server version
```

### Client-side variables

These vars provide connection information for the database you want to create or connect to. By convention, we store these values in files like `/group_vars/<project-name>/<env>.yml`.

```ini
  pg_hba_contype: "host"
  pg_hba_method: "md5"
  pg_hba_postgresql_database: "all"
  pg_hba_postgresql_user: "all"
  pg_hba_source: "{{ ansible_host }}/32"
  ol_db_host: '{{ postgres_host }}'
  ol_db_name: "{{ vault_ol_staging_db_name }}"
  ol_db_user: "{{ vault_ol_staging_db_user}}"
  ol_db_password: "{{ vault_ol_staging_db_password }}"
  application_db_name: "{{ ol_db_name }}"
  application_dbuser_name: "{{ ol_db_user }}"
  application_dbuser_password: "{{ ol_db_password }}"
  application_dbuser_role_attr_flags: "CREATEDB"
  postgresql_is_local: "false" # should always be false
  postgres_version: 15  # on application side this will install the postgresql client version
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
