MariaDB (MySQL) role
=========

This role installs and manages connections to mariadb. The role supports different modes of operation depending on the presence of MariaDB installed locally or not

Requirements
------------

Role Variables
--------------

Most use cases will have the variables below and only the mysql-common client
will be installed

```bash
mysql_server: false

mysql_host: "some.remotedb.edu"

mysql_root_password: "{{ vault_mysql_root_password }}"
mysql_databases:
  - name: "some_database"
    encoding: utf8mb4
    collation: utf8mb4_general_ci

mysql_users:
  - name: "some_user"
    host: "%"
    password: "change_me"
    priv: "some_database.*:ALL"
```

If installing a brand new mariadb server the `mysql_server` will be set to true
which means mariadb server will be installed

If installing a new mariadb server

```bash
mysql_server: true
```

Logging
-------

The role turns on the two logs we ship to SigNoz and makes sure MariaDB owns
the directory they live in:

- the error log, at `/var/log/mysql/mysql_error.log`
- the slow query log, at `/var/log/mysql/mysql_slow.log`, holding every query
  that takes longer than two seconds

MariaDB can only write these as plain text, so the OpenTelemetry collector
(installed by the `otel_collector` role) does the conversion: it pulls the
timestamp, severity, connection, schema, timing and row counts out of each
entry and sends them to SigNoz as structured fields. Slow queries can then be
sorted by how long they ran or how many rows they scanned, rather than being
searched as text.

To log queries at a different threshold, or to turn slow query logging off:

```bash
mysql_long_query_time: 5
mysql_slow_query_log: false
```

If you change `mysql_error_log` or `mysql_slow_query_log_file`, update the
matching `filelog` receiver paths in
`group_vars/mysql/{staging,production}.yml` so the shipper keeps finding them.

Cloud backup mount (gcsfuse)
----------------------------

Production database dumps can be written straight to a Google Cloud Storage
bucket mounted with gcsfuse, the same arrangement the `postgresql` role uses.
The mount runs as a systemd service so a dead FUSE process is restarted
automatically, stale mounts are detected and cleaned up on every run, and a
Checkmk local check reports whether today's dumps arrived.

We only back up production. The mount is skipped unless the backup flag is on,
the play is running against production, the host runs a MariaDB server, and the
host is Debian/Ubuntu, so these variables belong in
`group_vars/mysql/production.yml` only.

```ini
  mysql_gcs_backup_enabled: true
  mysql_gcs_backup_environment: "production"
  mysql_gcs_bucket_name: "pul-mariadb-backup"
  mysql_gcs_mountpoint: "/var/backups/mysql/cloud_backup"
  mysql_gcs_key_path: "/etc/mysql-backup-account-key.json"
  mysql_gcs_key_src: "files/mysql-backup-production-account-key.json"
  mysql_gcs_service_name: "mysql-gcs-backup.service"
  mysql_gcs_user: "mysql"
  mysql_gcs_group: "mysql"
  mysql_gcsfuse_directory: "/var/log/gcsfuse"
  mysql_backup_prefix: "mariadb"
  mysql_backup_file_suffix: ".sql.gz"
```

Before enabling it, add the vault-encrypted service account key for the bucket
to `roles/mysql/files/mysql-backup-production-account-key.json`. Until that key
exists, leave `mysql_gcs_backup_enabled` and `mysql_backup_schedule_enabled`
off, which is how `group_vars/mysql/production.yml` ships.

Run only the mount tasks by passing `--tags google_cloud`.

Scheduled dumps
---------------

A systemd timer dumps every database nightly and keeps rotated copies. Dumps
are written to a local staging directory first and moved into place only once
complete, so monitoring never sees a half-written file. Old copies are pruned
by the date in their directory name rather than by file timestamps, which
object storage only approximates.

```ini
  mysql_backup_schedule_enabled: true
  mysql_backup_on_calendar: "*-*-* 02:30:00"
  mysql_backup_days_to_keep: 7
  mysql_backup_weeks_to_keep: 5
  mysql_backup_months_to_keep: 3
  mysql_backup_day_of_week_to_keep: 7  # Sunday
  mysql_backup_enable_grants: true     # accounts and privileges
  mysql_backup_schema_only_databases: []
  mysql_backup_exclude_databases: [information_schema, performance_schema, sys]
  mysql_backup_run_now: false          # force a dump during the play
  mysql_backup_retries: 2              # retries after a lost connection
  mysql_backup_retry_delay: 60
  mysql_backup_startup_wait: 300       # wait for the server before dumping
```

Dumps read their credentials from `/etc/mysql/mysql-backup.cnf`, which by
default holds the root account so backups need no new vaulted password. To dump
with the least privilege instead, point the backup at a dedicated account and
the role will create it with read-only grants:

```ini
  mysql_backup_db_user: "backup"
  mysql_backup_db_password: "{{ vault_mysql_backup_password }}"
```

A dump can outlive a MariaDB restart, and a restart drops the dump's connection
in the middle of a table. The script waits for the server to accept connections
before it starts and retries a database whose connection went away, so a
restart costs a pause instead of the whole backup. For the same reason the role
applies any pending MariaDB restart before it starts a dump, and schedules
backups as the last step of the play.

Backups land in one tier per day: monthly on the first of the month, weekly on
`mysql_backup_day_of_week_to_keep`, daily otherwise.

```text
<mountpoint>/<prefix>/production/daily/YYYYMMDD/<database>-YYYYMMDD.sql.gz
<mountpoint>/<prefix>/production/daily/YYYYMMDD/grants-YYYYMMDD.sql.gz
<mountpoint>/<prefix>/production/weekly/YYYYMMDD/...
<mountpoint>/<prefix>/production/monthly/YYYYMMDD/...
```

Databases listed in `mysql_backup_schema_only_databases` are dumped without
table data and named `<database>_schema-YYYYMMDD.sql.gz`. The `grants` file
holds `CREATE USER` and `GRANT` statements for every account, which
per-database dumps omit; it is the MariaDB counterpart of PostgreSQL's globals
dump.

The role runs a dump immediately the first time it finds an empty backup tree,
so a freshly configured host does not sit unbacked (and CRITICAL in Checkmk)
until the timer's next scheduled hour. Useful commands on the host:

```bash
systemctl list-timers mysql-backup.timer          # next scheduled run
journalctl -fu mysql-backup.service               # watch a run
systemctl start --no-block mysql-backup.service   # run now, returns at once
/usr/local/bin/mysql_backup_rotated.sh --tier daily   # ad hoc dump
/usr/local/bin/mysql_backup_rotated.sh --prune-only   # apply retention only
/usr/lib/check_mk_agent/local/check_mysql_backup.sh   # verify
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
  needs no second local copy, so set `mysql_backup_space_factor: 1`.
- **Before 3.0** the default write path stages the whole file on local disk and
  uploads it when the file is closed, so publishing a 50GB dump needs another
  50GB. That is what `mysql_backup_space_factor: 2` covers.

Check with `gcsfuse --version`. The role also points gcsfuse at
`mysql_gcsfuse_temp_directory` rather than the default `/tmp`, so any staging it
does is predictable and sits next to the backups.

A backup must never fill the filesystem holding MariaDB's data directory,
because that takes the database down. Two mechanisms prevent it:

- The run refuses to start if free space is already below
  `mysql_backup_min_free_mb`.
- While a dump is running, free space is polled every
  `mysql_backup_space_guard_interval` seconds and the dump is killed if it
  crosses that floor. The partial dump is deleted, no retry is attempted
  (running out of disk will not fix itself), remaining databases are skipped,
  and the run exits non-zero so the timer reports failure and Checkmk reports
  the missing backups.

An incomplete backup is the intended outcome there, in preference to an outage.
Sizing off the raw table data is deliberately pessimistic, so the separate
low-space message is a warning only: gzipped dumps are usually far smaller than
the database they came from.

Backups run at low I/O priority (`mysql_backup_io_class`,
`mysql_backup_io_priority`) so they yield to MariaDB. The `idle` class yields so
completely that a dump can stall indefinitely on a busy server, so the default
is the lowest best-effort priority instead.

Restarting the gcsfuse mount aborts any dump in progress, since the backup
service requires the mount. Avoid redeploying while a backup is running.

The check reports CRITICAL when no dumps exist for today, WARNING when the
per-database dumps are present but the grants dump is missing, and OK otherwise.
