# catalog_cluster

Sets up catalog cluster VMs. Installs Rust (via the `rust` role) and a
PostgreSQL client (via the `psql-client` role), which also creates the
application database and user on `postgres_host`.

Database credentials live in `group_vars/catalog_cluster/vault.yml`.

Run with `ansible-playbook playbooks/catalog_cluster.yml`.
