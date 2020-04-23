PostgreSQL
=========

Installs PostgreSQL from the official postgresql repository, and configures it.


Requirements
------------



Role Variables
--------------

These variables are set in [defaults/main.yml](defaults/main.yml)

```yaml
postgres_databases:
  - name: lib_confluence_staging_db
postgres_users:
  - name: lib_conf_staging_user_db
    password: "{{ vault_lib_conf_user_password }}"
    db: lib_confluence_staging_db
postgres_hba_entries:
  - type: host
    database: lib_confluence_staging
    user: lib_conf_staging_user_db
    address: "1.2.3.4/32"
    method: md5
```

Adding the following variables will allow the creating of the db user `lib_conf_staging_user_db` who owns the `lib_confluence_staging_db` 

It is recommended to then create the same user on [pulibrary.pgbouncer](pulibrary.pgbouncer) role for more reliability/robustness