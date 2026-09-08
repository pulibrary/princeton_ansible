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

* the error log, at `/var/log/mysql/mysql_error.log`
* the slow query log, at `/var/log/mysql/mysql_slow.log`, holding every query
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
