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
  - name: confluence_staging_db
postgres_users:
  - name: confluence_staging_user_db
    password: "{{ vault_confluence_staging_user_db_password }}"
    db: confluence_staging_db
    priv: "ALL"
    role_attr_flags: "CREATEDB"
postgres_hba_entries:
  - type: host
    database: confluence_staging_db
    user: confluence_staging_user_db
    address: "1.2.3.4/32"
    method: md5
```

Adding the following variables will allow the creating of the db user `confluence_staging_user_db` who owns the `confluence_staging_db` 

It is recommended to then create the same user on [pgbouncer](pgbouncer) role for more reliability/robustness
