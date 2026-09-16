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
  postgres_version: 15  # on application side this will install the postgresql client version
```

### Cloud backup mount (gcsfuse)

Production database dumps can be written straight to a Google Cloud Storage
bucket mounted with gcsfuse. The mount runs as a systemd service so a dead
FUSE process is restarted automatically, stale mounts are detected and
cleaned up on every run, and a Checkmk local check reports whether today's
dumps arrived.

We only back up production. The mount is skipped unless the backup flag is
on, the play is running against production, and the host is Debian/Ubuntu,
so these variables belong in `group_vars/postgresql*/production.yml` only.

```ini
  postgres_gcs_backup_enabled: true
  postgres_gcs_backup_environment: "production"
  postgres_gcs_bucket_name: "pul-postgres-backup"
  postgres_gcs_mountpoint: "/var/backups/postgresql/cloud_backup"
  postgres_gcs_key_path: "/etc/postgres-backup-account-key.json"
  postgres_gcs_key_src: "files/postgres-backup-production-account-key.json"
  postgres_gcs_service_name: "postgres-gcs-backup.service"
  postgres_gcs_user: "postgres"
  postgres_gcs_group: "postgres"
  postgres_gcsfuse_directory: "/var/log/gcsfuse"
  postgres_backup_prefix: "postgresql15"
  postgres_backup_file_suffix: ".dump"
```

Before enabling it, add the vault-encrypted service account key for the
bucket to
`roles/postgresql/files/postgres-backup-production-account-key.json`.

Run only the mount tasks by passing `--tags google_cloud`.

### Scheduled dumps

A systemd timer dumps every database nightly and keeps rotated copies, the
same approach as the PostgreSQL wiki's automated backup scripts. Dumps are
written to a local staging directory first and moved into place only once
complete, so monitoring never sees a half-written file. Old copies are
pruned by the date in their directory name rather than by file timestamps,
which object storage only approximates.

```ini
  postgres_backup_schedule_enabled: true
  postgres_backup_on_calendar: "*-*-* 01:30:00"
  postgres_backup_days_to_keep: 7
  postgres_backup_weeks_to_keep: 5
  postgres_backup_months_to_keep: 3
  postgres_backup_day_of_week_to_keep: 7  # Sunday
  postgres_backup_enable_custom: true     # pg_dump --format=custom
  postgres_backup_enable_plain: false     # gzipped plain SQL as well
  postgres_backup_enable_globals: true    # roles and tablespaces
  postgres_backup_schema_only_databases: []
  postgres_backup_exclude_databases: []
  postgres_backup_run_now: false          # force a dump during the play
  postgres_backup_retries: 2              # retries after a lost connection
  postgres_backup_retry_delay: 60
  postgres_backup_startup_wait: 300       # wait for the server before dumping
```

A dump can outlive a PostgreSQL restart, and a restart drops the dump's
connection in the middle of a table. The script waits for the server to
accept connections before it starts and retries a database whose connection
went away, so a restart costs a pause instead of the whole backup. For the
same reason the role applies any pending PostgreSQL restart before it starts
a dump, and schedules backups as the last step of the play.

Backups land in one tier per day: monthly on the first of the month, weekly
on `postgres_backup_day_of_week_to_keep`, daily otherwise.

```text
<mountpoint>/<prefix>/production/daily/YYYYMMDD/<database>-YYYYMMDD.dump
<mountpoint>/<prefix>/production/daily/YYYYMMDD/globals-YYYYMMDD.sql.gz
<mountpoint>/<prefix>/production/weekly/YYYYMMDD/...
<mountpoint>/<prefix>/production/monthly/YYYYMMDD/...
```

Databases listed in `postgres_backup_schema_only_databases` are dumped
without table data and named `<database>_schema-YYYYMMDD.dump`.

The role runs a dump immediately the first time it finds an empty backup
tree, so a freshly configured host does not sit unbacked (and CRITICAL in
Checkmk) until the timer's next scheduled hour. Useful commands on the host:

```bash
systemctl list-timers postgres-backup.timer     # next scheduled run
journalctl -fu postgres-backup.service          # watch a run
systemctl start --no-block postgres-backup.service  # run now, returns at once
/usr/local/bin/pg_backup_rotated.sh --tier daily    # ad hoc dump
/usr/local/bin/pg_backup_rotated.sh --prune-only    # apply retention only
/usr/lib/check_mk_agent/local/check_postgresql_backup.sh  # verify
```

Use `--no-block` when starting the service by hand. The service is
`Type=oneshot`, so a plain `systemctl start` blocks until every database has
been dumped, which on a large database looks like a hung terminal.

Each run logs the size of each database before dumping it, then the size and
duration of each upload, so a slow run can be told apart from a stuck one.
Uploads are logged separately because staging is local disk while the backup
tree is object storage: publishing a dump is a full upload, not a rename, and
on a large database it can take longer than the dump itself.

### Local disk needed for a large database

Dumps are staged on local disk before being published to the bucket, so a run
needs room for the largest single dump. How much more than that depends on the
gcsfuse version:

- **gcsfuse 3.0 and later** stream writes straight to the bucket. Publishing
  needs no second local copy, so set `postgres_backup_space_factor: 1`.
- **Before 3.0** the default write path stages the whole file on local disk and
  uploads it when the file is closed, so publishing a 50GB dump needs another
  50GB. That is what `postgres_backup_space_factor: 2` covers.

Check with `gcsfuse --version`. The role also points gcsfuse at
`postgres_gcsfuse_temp_directory` rather than the default `/tmp`, so any staging
it does is predictable and sits next to the backups.

A backup must never fill the filesystem holding PostgreSQL's data directory,
because that takes the database down. Two mechanisms prevent it:

- The run refuses to start if free space is already below
  `postgres_backup_min_free_mb`.
- While a dump is running, free space is polled every
  `postgres_backup_space_guard_interval` seconds and the dump is killed if it
  crosses that floor. The partial dump is deleted, no retry is attempted
  (running out of disk will not fix itself), remaining databases are skipped,
  and the run exits non-zero so the timer reports failure and Checkmk reports
  the missing backups.

An incomplete backup is the intended outcome there, in preference to an outage.
Sizing off the raw database size is deliberately pessimistic, so the separate
low-space message is a warning only: compressed dumps are usually far smaller
than the database they came from.

Backups run at low I/O priority (`postgres_backup_io_class`,
`postgres_backup_io_priority`) so they yield to PostgreSQL. The `idle` class
yields so completely that a dump can stall indefinitely on a busy server, so
the default is the lowest best-effort priority instead.

Restarting the gcsfuse mount aborts any dump in progress, since the backup
service requires the mount. Avoid redeploying while a backup is running.

The check reports CRITICAL when no dumps exist for today, WARNING when the
per-database dumps are present but the globals dump (roles and tablespaces)
is missing, and OK otherwise.

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
