# Fleet Kubernetes (microk8s)

This role deploys [Fleet](https://fleetdm.com/) (open source device management
for macOS, Windows, Linux, iOS, Android and ChromeOS) onto a **microk8s**
cluster using the official Fleet Helm chart, following
[Deploy Fleet on Kubernetes](https://fleetdm.com/guides/deploy-fleet-on-kubernetes).

Fleet is stateless: all data lives in an external MySQL database and an
external Redis cache. Neither is deployed into the cluster by this role.

## Role Description

The role performs the following steps:

1. Validates that MySQL and Redis connection details and the MDM server private
   key have been supplied.
2. Confirms every cluster node is `Ready` and that MySQL and Redis are
   reachable from the cluster.
3. Creates the Fleet namespace if it does not exist.
4. Renders and applies the MySQL password secret, the optional Redis password
   secret, and the optional Fleet Premium license secret.
5. Renders a Helm `values.yaml` into `/etc/fleet/values.yaml` (mode `0600`,
   because it carries the MDM server private key).
6. Adds and updates the Fleet Helm repository.
7. Drains the Fleet deployment when the image tag changes, because Fleet
   applies database schema migrations on start-up and those migrations fail if
   older pods still hold connections to the database.
8. Installs or upgrades the Helm release and waits for every replica to become
   ready.
9. Optionally installs a Checkmk local check that alerts when Fleet pods are
   not ready.

All interactions with microk8s are done through `microk8s helm3` and
`microk8s kubectl`, so the role runs on the cluster's primary node.

## Requirements

- **Target host** must have [microk8s](../microk8s_cluster/) installed and
  running, which provides `microk8s helm3` and `microk8s kubectl`.
- An external MySQL server with a `fleet` database and a `fleet` user. The
  [fleet_mysql](../fleet_mysql/) role builds one.
- An external Redis-compatible cache with a database index that no other
  application is using.

> **The database must be Oracle MySQL 8.0.44 or later. MariaDB does not work.**
> Fleet's migration history cannot be replayed on MariaDB: a 2024 migration adds
> a generated column using syntax MariaDB's parser rejects, so the migration job
> fails and Fleet never starts. MariaDB support is still an open project
> upstream ([fleetdm/fleet#31288](https://github.com/fleetdm/fleet/issues/31288)),
> so our shared `mysql-db-prod1` MariaDB server cannot host Fleet. The
> [fleet_mysql](../fleet_mysql/) role checks the server version and stops before
> deploying if it is unsuitable.

## Role Variables

The most important variables are listed below; see `defaults/main.yml` for the
full set.

| Variable                    | Default                                   | Description                                                        |
| --------------------------- | ----------------------------------------- | ------------------------------------------------------------------ |
| `fleet_namespace`           | `fleet`                                   | Namespace Fleet is deployed into (created if missing).             |
| `fleet_release_name`        | `fleet`                                   | Helm release name.                                                 |
| `fleet_chart_repo_url`      | `https://fleetdm.github.io/fleet/charts`  | Fleet Helm repository.                                             |
| `fleet_chart_version`       | `""`                                      | Chart version to pin. Empty installs the latest chart.             |
| `fleet_image_tag`           | `v4.91.1`                                 | Fleet server version to run.                                       |
| `fleet_replicas`            | `3`                                       | Number of Fleet server pods.                                       |
| `fleet_hostname`            | `fleet.lib.princeton.edu`                 | Public hostname; also used for the ingress rule.                   |
| `fleet_tls_enabled`         | `false`                                   | Serve TLS from the pods. Left off because TLS ends at the ingress. |
| `fleet_ingress_enabled`     | `true`                                    | Create an ingress for `fleet_hostname`.                            |
| `fleet_database_host`       | `""`                                      | MySQL hostname. Required.                                          |
| `fleet_database_name`       | `fleet`                                   | MySQL database name.                                               |
| `fleet_database_username`   | `fleet`                                   | MySQL username.                                                    |
| `fleet_database_password`   | `""`                                      | MySQL password. Required; store it in a vault file.                |
| `fleet_cache_host`          | `""`                                      | Redis hostname. Required.                                          |
| `fleet_cache_database`      | `"0"`                                     | Redis database index.                                              |
| `fleet_cache_use_password`  | `false`                                   | Authenticate to Redis.                                             |
| `fleet_server_private_key`  | `""`                                      | Key Fleet uses to encrypt MDM secrets. Required, 32+ characters.   |
| `fleet_license_key`         | `""`                                      | Fleet Premium license. Empty runs Fleet Free.                      |
| `fleet_checkmk_enabled`     | `false`                                   | Install the Checkmk local check.                                   |

> **Note:** `fleet_server_private_key` must never change once Fleet has stored
> MDM secrets with it; rotating it makes previously encrypted values
> unreadable.

## Upload limits

The ingress annotations allow a 3 GB request body and turn request buffering
off, because Fleet accepts software installer packages up to that size and
buffering them would spool gigabytes to disk before any of it reached Fleet.
The load balancer in front of the cluster
(`roles/nginxplus/files/conf/http/fleet_prod.conf`) has to agree, or it will
reject what the ingress would have allowed.

## Dependencies

None.

## Example Playbook

```yaml
- name: Deploy Fleet on microk8s
  hosts: k8s_microk8s_primary_production
  become: true
  roles:
    - role: fleet_k8s
```
