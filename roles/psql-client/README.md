# Postgresql

=========

Connects to a remote postgres server and uses provided admin credentials to create a new database and user account for a given application. It can also manage database backups.

Based on [the `postgresql` role from `pulibrary/princeton_ansible`](https://github.com/pulibrary/princeton_ansible/tree/main/roles/postgresql).

## Requirements

------------

This role requires the `community.postgresql` collection to manage the database and users.

## Variables

------------

### Database Connection & Credentials

- `postgres_port`: port at which remote postgres server is accessible (default: `5432`)
- `postgres_host`: hostname for remote postgres server (default: `postgres`)
- `postgres_version`: version of postgres in use (default: `15`)
- `vault_postgres_admin_user`: account on postgres server with db creation permissions (default: `postgres`)
- `vault_postgres_admin_password`: password for admin postgres account (default: `postgres`)

### Application Settings

- `application_db_name`: postgres database to create for app (default: `app`)
- `application_dbuser_name`: postgres account for app that will be created with access to app's database (default: `app_user`)
- `application_dbuser_password`: password for app's postgres account (default: `changethis`)
- `application_dbuser_role_attr_flags`: capabilities to grant to app's postgres account (default: `""`)

### Deployment & Backup Settings

- `deploy_user`: the system user on the app host that will own the backup files (default: `deploy`)
- `deploy_user_venv`: path to the virtual environment for the deploy user (default: `/home/{{ deploy_user }}/venv`)
- `db_backup_path`: the path on the app host where the database backup will be saved (default: `/home/{{ deploy_user }}/last_{{ application_db_name }}.sql`)

### Feature Flags

- `postgres_setup_enabled`: whether to run the installation, configuration, and user/db creation tasks (default: `true`)
- `postgres_backup_enabled`: whether to run the database backup tasks (default: `true`)

## Example Playbook

------------

```yml
    - hosts: servers
      vars:
        postgres_setup_enabled: true
        postgres_backup_enabled: true
        application_db_name: my_app_db
        deploy_user: my_deploy_user
      roles:
         - postgresql
```
