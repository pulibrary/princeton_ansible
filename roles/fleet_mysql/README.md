Oracle MySQL role
=========

This role installs and manages connections to Oracle MySQL. It is a sibling of
the [mysql](../mysql/) role and takes the same variables, so anything written
against that role works here unchanged. The difference is the database it
installs: **Oracle MySQL 8.4 LTS instead of MariaDB.**

Why a separate role
-------------------

Our `mysql` role installs MariaDB. Fleet cannot run on MariaDB at
all. [Fleet](https://fleetdm.com/) is the first of them: its schema migration
history contains a 2024 migration that adds a generated column using syntax
MariaDB's parser rejects, so the migrations fail and the server never starts.
Applied migrations cannot be rewritten, and MariaDB support is still an open
project upstream ([fleetdm/fleet#31288](https://github.com/fleetdm/fleet/issues/31288)),
so there is no version of MariaDB that will work.

MariaDB and MySQL conflict at the package level (both claim `mysql-server` and
`mysql-client`), so they cannot share a host. This role therefore needs its own
server, and it refuses to run on a host that already has MariaDB installed
rather than swapping the database out from under an existing data directory.

Ubuntu's own `mysql-server` package is also not suitable: it ships 8.0.4x, and
Fleet requires 8.0.44 or later. The role uses Oracle's APT repository and the
8.4 LTS series, which is one of the versions Fleet tests against and is
supported upstream until 2032.

Requirements
------------

- Ubuntu 22.04 (jammy) or 24.04 (noble) on amd64. Oracle publishes its Ubuntu
  packages for amd64 only.

Role Variables
--------------

The variables are the same as the [mysql](../mysql/) role's. Most use cases
will have the variables below and only the client will be installed:

```bash
mysql_server: false

mysql_host: "some.remotedb.edu"

mysql_root_password: "{{ vault_mysql_root_password }}"
mysql_databases:
  - name: "some_database"
    encoding: utf8mb4
    collation: utf8mb4_unicode_ci

mysql_users:
  - name: "some_user"
    host: "10.0.0.1"
    password: "change_me"
    priv: "some_database.*:ALL"
```

To install a server, set `mysql_server: true`.

### Variables specific to this role

| Variable                      | Default                       | Description                                                          |
| ----------------------------- | ----------------------------- | -------------------------------------------------------------------- |
| `mysql_apt_repo_component`    | `mysql-8.4-lts`               | Which MySQL series to install from Oracle's repository.              |
| `mysql_apt_key_url`           | Oracle's 2025 key             | Repository signing key. See the note below.                          |
| `mysql_apt_key_fingerprint`   | `BCA4...785C`                 | Fingerprint the downloaded key is checked against.                   |
| `mysql_enable_mysqlx`         | `false`                       | MySQL's X Protocol listener on port 33060. Nothing here uses it.     |
| `mysql_root_hosts`            | loopback addresses            | Which hosts get a `root` account.                                    |
| `mysql_default_time_zone`     | `+00:00`                      | Server clock. Fleet compares its UTC timestamps against it.          |
| `mysql_authentication_plugin` | `caching_sha2_password`       | Plugin every account is created with. See the note below.            |
| `mysql_root_salt`             | `""`                          | 20-character salt that makes the root password task idempotent.      |

> **Renewing the apt key.** Oracle publishes its signing key under a filename
> containing a year, and republishes the *same* key under a new year when it
> extends the expiry. The older files keep the older, now-expired expiry date,
> and apt rejects an expired key with a signature error that does not mention
> expiry at all. The role reads the key's expiry date before trusting it and
> fails with an explanation if it has passed, so renewal means pointing
> `mysql_apt_key_url` at the newest file.

### Password idempotence

> **Password tasks report "changed" on every run.** MySQL 8.4 removed the
> `mysql_native_password` plugin, but the Ansible MySQL modules still reach for
> it on any server below 9.7, so passing a plain `password` fails outright. The
> role therefore names `caching_sha2_password` explicitly. The modules cannot
> then tell a stored hash apart from the password it came from, so the three
> password tasks always report a change. Supplying a 20-character salt makes
> the hash reproducible and the tasks idempotent: set `mysql_root_salt`, and add
> a `salt` key to each entry in `mysql_users`. A salt is not a secret and can
> live in plain group_vars.

Differences from the mysql role
-------------------------------

The task list mirrors the `mysql` role step for step. These are the places
where the behaviour differs, and why:

- **Root password.** MariaDB leaves a new root account passwordless and the
  role sets the password afterwards. Oracle's packaging asks for the root
  password during installation, so the role answers that question through
  debconf before installing. It still runs the same check afterwards to work
  out which login succeeds, so reruns against a live server behave identically.
  This needs `debconf-utils`, which is not on a minimal Ubuntu, so the role
  installs it.
- **Authentication plugin.** Accounts are created with
  `caching_sha2_password` named explicitly rather than through the modules'
  `password` option. See the note above.
- **Python driver.** `python3-pymysql` instead of `python3-mysqldb`. PyMySQL is
  pure Python and implements MySQL 8's default `caching_sha2_password`
  authentication; on Ubuntu, `python3-mysqldb` links against MariaDB's client
  library.
- **Configuration filename.** The settings go in a file prefixed `zz-`. MySQL
  reads an included directory in alphabetical order, and the server package
  ships its own `mysqld.cnf` in the same directory setting `log-error`. Without
  a prefix that sorts later, the package file wins and the log shipper ends up
  watching a file the server never writes.
- **Root accounts.** The `mysql` role creates `root@<hostname>`, which is
  reachable from the network. This role keeps root to the loopback addresses
  and expects applications to have their own accounts through `mysql_users`.
  Override `mysql_root_hosts` if you need the old behaviour.
- **Version check.** The role refuses to continue if the running server is
  MariaDB or older than 8.0.44, so a mismatch is reported here rather than as
  a failed migration much later.
- **Architecture check.** Oracle builds its Ubuntu packages for amd64 only, so
  the role stops on any other architecture instead of failing later on a
  missing apt index. For the same reason the repository is registered for
  amd64 alone, not the `amd64,arm64` the MariaDB role uses.
- **Anonymous users and the test database.** MySQL 8 ships without either, so
  the removal tasks are normally no-ops. They are kept because an upgraded or
  hand-built server can still have them.
- **Backups.** The dump options drop the binary log position
  (`--set-gtid-purged=OFF`) and tablespace clauses (`--no-tablespaces`), both
  of which MySQL includes by default and which need privileges a restore does
  not have. The grants dump skips MySQL's three reserved internal accounts,
  which a restore cannot recreate. The `mysql` database is excluded from the
  per-database dumps because the grants dump already covers those accounts in
  a restorable form. Dumps land under a `mysql` prefix in the backup bucket so
  they are never mixed up with the MariaDB servers' dumps. The script requires
  the `mysql*` clients by name, because a host that once ran MariaDB can still
  have `mariadb-dump` on its PATH.
- **X Protocol and clock.** Turned off and pinned to UTC respectively; neither
  setting exists in the MariaDB role.
- **Repository key trust.** Scoped to this one repository with `signed-by`
  rather than added to `trusted.gpg.d`, where it would be trusted for every
  repository on the host.

Log shipping
------------

The role writes `mysql_error.log` and `mysql_slow.log` exactly where the
MariaDB servers write them, so the SigNoz collector needs no new file paths.
The *contents* differ, though, and the `otel_receivers` parsers in
`group_vars/mysql/` were written against MariaDB:

- MySQL timestamps carry microseconds and a `Z` suffix
  (`2026-09-18T23:06:21.797560Z`), and its severities are `System`, `Note`,
  `Warning` and `ERROR`.
- MySQL's slow log puts the connection id on the `User@Host` line as `Id: 77`
  rather than on a separate `# Thread_id: N Schema: X` line.

The error log will still parse into timestamp, thread id and level, but the
severity mapping and the slow log's per-query attributes need adjusting before
this server's logs are as useful in SigNoz as the MariaDB servers' are.

Dependencies
------------

`common`.

Example Playbook
----------------

```yaml
- name: Install MySQL for Fleet
  hosts: fleet_mysql_production
  become: true
  vars:
    mysql_server: true
    mysql_bind_address: "0.0.0.0"
    mysql_root_password: "{{ vault_fleet_mysql_root_password }}"
    mysql_databases:
      - name: fleet
        encoding: utf8mb4
        collation: utf8mb4_unicode_ci
    mysql_users:
      - name: fleet
        host: "10.0.0.1"
        password: "{{ vault_fleet_database_password }}"
        priv: "fleet.*:ALL"
  roles:
    - role: fleet_mysql
```

Testing
-------

```bash
cd roles/fleet_mysql
env -u ANSIBLE_VAULT_IDENTITY_LIST -u ANSIBLE_VAULT_PASSWORD_FILE molecule test
```
