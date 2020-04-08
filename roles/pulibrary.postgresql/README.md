PostgreSQL
=========

Installs PostgreSQL from the official PostGres repository, and configures it.


Requirements
------------

It expects `apt`

Role Variables
--------------


* postgresql_is_local - set it to `false` defaults to true (which is only valid for testing)
* postgres_host - currently set it to `lib-postgres3.princeton.edu`
* postgres_version - Currently set it to `10`


If you are seeing `FATAL: no pg_hba.conf entry for host` when running a new role make sure you have `postgresql_is_local: false` in your variables.