# SigNoz Kubernetes (microk8s)

This role deploys [SigNoz](https://signoz.io/) (an open‑source APM and observability platform) on a **microk8s** cluster using Helm3. It handles repository setup, Helm chart installation (or upgrade), and basic post‑deployment verification.

## Role Description

The role performs the following steps:

1. Creates a local directory (`/etc/signoz`) for the Helm values file.
2. Renders a `values.yaml` template using role variables.
3. Adds the SigNoz Helm repository (`https://charts.signoz.io`).
4. Updates the Helm repository index.
5. Installs or upgrades the SigNoz Helm release (with optional chart version pinning).
6. Waits for the SigNoz Kubernetes service to become available.
7. Displays the status of all pods in the target namespace.

All interactions with microk8s are done via `microk8s helm3` and `microk8s kubectl`.

## Requirements

- **Target host** must have:
  - [microk8s](../microk8s_cluster/) installed and running.
  - `microk8s helm3` and `microk8s kubectl` commands available (included with microk8s).

## Role Variables

All variables are defined in `defaults/main.yml` and can be overridden in your playbook or inventory.

| Variable                 | Default value              | Description                                                                    |
| ------------------------ | -------------------------- | ------------------------------------------------------------------------------ |
| `signoz_namespace`       | `platform`                 | Kubernetes namespace where SigNoz will be deployed (created if missing).       |
| `signoz_release_name`    | `signoz`                   | Helm release name.                                                             |
| `signoz_chart_repo_name` | `signoz`                   | Local name for the SigNoz Helm repository.                                     |
| `signoz_chart_repo_url`  | `https://charts.signoz.io` | URL of the SigNoz Helm repository.                                             |
| `signoz_chart_ref`       | `signoz/signoz`            | Helm chart reference (`<repo>/<chart>`).                                       |
| `signoz_chart_version`   | `"0.147.0"`                | Specific chart version to install. If empty, the latest version is used.       |
| `signoz_storage_class`   | `nfs`                      | Storage class to use for persistent volumes (passed to `global.storageClass`). |
| `signoz_service_type`    | `NodePort`                 | Kubernetes service type for the SigNoz frontend.                               |
| `signoz_http_node_port`  | `32080`                    | NodePort number when `signoz_service_type` is `NodePort`.                      |

> **Note:** The `global.storageClass` value is set only in the Helm values template; the role does not create the storage class itself – it must exist in the cluster.

## ClickHouse diagnostic log retention

ClickHouse writes its own diagnostics to `system.*_log` tables
(`query_log`, `part_log`, `zookeeper_log`, `trace_log`, …). They are separate
from SigNoz's `signoz_logs`, `signoz_traces` and `signoz_metrics` databases,
whose retention is set in the SigNoz UI and is not touched here. In the
disk-full incident `system.zookeeper_log` alone reached about 124 GiB under its 30-day
TTL.

| Variable | Default | Meaning |
| --- | --- | --- |
| `signoz_clickhouse_system_log_retention_days` | `7` | Days kept in every managed table. |
| `signoz_clickhouse_system_log_retention_overrides` | `{}` | Per-table days, e.g. `{crash_log: 30}`. |
| `signoz_clickhouse_operator_system_logs` | 14 tables | Tables the chart's operator config defines. |
| `signoz_clickhouse_stock_system_logs` | 3 tables | Tables from the ClickHouse image's `config.xml`. |
| `signoz_clickhouse_system_log_migration_enabled` | `true` | Align existing tables before Helm runs. |

**Shortening retention permanently deletes older diagnostic history.
Raising it again later does not bring deleted records back.**

### Where the policy lives

- The 14 tables the chart templates (`query_log`, `part_log`, `trace_log`,
  `asynchronous_insert_log`, `asynchronous_metric_log`, `backup_log`,
  `blob_storage_log`, `crash_log`, `metric_log`, `query_thread_log`,
  `query_views_log`, `session_log`, `zookeeper_log`, `processors_profile_log`)
  get their TTL from the chart value `clickhouse.clickhouseOperator.<name>.ttl`.
  Partitioning (`event_date`) and ordering (`event_time`) stay as the chart
  defines them.
- `aggregated_zookeeper_log`, `zookeeper_connection_log` and
  `background_schedule_pool_log` come from the ClickHouse image's own config.
  The role adds only a `<ttl>` element for them through the chart value
  `clickhouse.clickhouseOperator.configs.confdFiles`; their monthly
  partitioning and ordering are unchanged.
- `text_log` (3 days), `query_metric_log` (3 days) and `error_log` (7 days) are
  already set by the chart's own `config.d/system_log.xml`, which ClickHouse
  reads after the operator's `conf.d`. They are left to the chart.

The ClickHouse operator copies these files into the ClickHouse pod without
restarting it (its restart rules only cover the ClickHouseInstallation spec).
ClickHouse uses them the next time it starts.

### Existing tables (`tasks/system_log_retention.yml`)

Configuration alone does not change an existing table. When ClickHouse 25.12
starts and finds a system log table whose definition differs from the
configuration, it renames the table to `<name>_0` (keeping all of its data and
its old TTL) and creates an empty one. That would leave the large tables
behind under a 30-day TTL.

So before the Helm upgrade the role:

1. Reads each table's TTL from `system.tables` (read-only, also in check mode).
2. Skips tables that do not exist yet; they will be created with the new TTL.
3. Stops the run if a table has a TTL the role did not write (for example a
   `TO VOLUME` clause) rather than overwrite it.
4. Checks that the running server has already read the table's definition: it
   needs a row written after both the server start and the table's last
   metadata change. ClickHouse re-reads a definition only on the first flush
   after it starts or creates a table, and altering a table before that read
   makes the server rename it. Tables without such a row are listed as
   deferred and handled by a later run.
5. Runs `ALTER TABLE system.<name> MODIFY TTL event_date + INTERVAL <n> DAY
   SETTINGS materialize_ttl_after_modify = 0` only where the TTL differs.

Check mode reports the ALTERs it would run and sends none. A second run makes
no changes. The role never truncates or drops tables, never runs `OPTIMIZE`,
and never materializes TTL.

### When space comes back

`materialize_ttl_after_modify = 0` makes the ALTER a metadata change, with no
rewrite of existing data. Each part on disk keeps the expiry ClickHouse worked
out when it was written:

- In the daily-partitioned operator tables, data written before the change
  still expires 30 days (15 for `query_views_log`) after its `event_date`.
  Data written after the change expires after 7 days. Within 30 days of the
  rollout each table holds only 7 days of data, and space returns one day at a
  time as old partitions expire, without a burst of merge I/O.
- `aggregated_zookeeper_log` and `zookeeper_connection_log` already had a
  30-day TTL and behave the same way.
- `background_schedule_pool_log` had no TTL. Its parts from before the change
  have no expiry recorded and stay until a merge rewrites them. Closed monthly
  partitions are not merged again, so their rows remain. The table is small;
  if it ever matters, an operator can remove whole old months by hand (see
  below).

To reclaim space sooner, an operator can act on one partition at a time,
outside routine convergence and after checking its size in `system.parts`:

```sql
-- Drop a whole day that is past retention (daily-partitioned tables)
ALTER TABLE system.query_log DROP PARTITION '2026-09-01';
-- Or apply the new TTL to one partition (rewrites that partition)
ALTER TABLE system.query_log MATERIALIZE TTL IN PARTITION '2026-09-01';
```

### Restarts and leftover tables

If ClickHouse restarts before the operator has placed the new files in the pod,
or a deferred table is still unaltered when it restarts, ClickHouse renames
that table to `<name>_N`. The renamed table keeps its data and its TTL and
empties itself as the data expires. Find such tables with:

```sql
SELECT name, total_bytes FROM system.tables
WHERE database = 'system' AND match(name, '_log_[0-9]+$');
```

## Collector telemetry and SigNoz alerts

The chart's default collector serves its own metrics only on `localhost:8888`
inside the pod. No k8s-infra agent is deployed and nothing else scrapes the
pod, so before this change those metrics were not collected at all.
`signoz_otel_internal_metrics_enabled` keeps that endpoint exactly as it was
and also sends the metrics every 30 s through the collector's OTLP receiver
into SigNoz.

Verified against `signoz/signoz-otel-collector:v0.144.14` (chart 0.147.0):

| Metric (as stored in SigNoz) | Type | Labels |
| --- | --- | --- |
| `otelcol_exporter_send_failed_log_records` | cumulative counter | `exporter` |
| `otelcol_exporter_enqueue_failed_log_records` | cumulative counter, created at its first failure | `exporter` |
| `otelcol_exporter_queue_size`, `otelcol_exporter_queue_capacity` | gauge | `exporter`, `data_type` |

Every series also carries the resource attributes `service.instance.id`,
`service.name` and `service.version`. A restarted collector gets a new
`service.instance.id`, so counter resets start new series. A `_total` suffix
appears only on a Prometheus endpoint with type suffixes enabled; the chart
default disables them.

With `signoz_alert_rules_enabled`, the role manages three PromQL rules through
the SigNoz API (`/api/v2/rules`), matched by name:

| Rule | Query | Fires when |
| --- | --- | --- |
| send failures | `rate(otelcol_exporter_send_failed_log_records{exporter="clickhouselogsexporter"}[2m])` | above 0 at every point for 5 min |
| enqueue failures | `increase(…enqueue_failed…[5m]) > 0`, or the series is new in the last 5 min | above 0 once; evaluated every minute over a 1-min window |
| queue utilization | `queue_size / queue_capacity` for the logs exporter | at or above 0.8 at every point for 5 min; **no data for 10 min also alerts** |

The queue ratio is computed per collector (series are matched on all labels,
including `service.instance.id`), so one full queue cannot be hidden by an
average. The enqueue counter exists only after its first failure, so
`increase()` alone would miss the first drop; the second clause catches it.

Rules use only existing notification channels named in
`signoz_alert_channels`; the run fails if any is missing. The API key goes in
`signoz_api_key` (from the vault). Check mode reports drift without writing.
These alerts depend on SigNoz and ClickHouse being up; the Checkmk checks
below do not.

### Exporter queues

The logs exporter uses the collector's default sending queue. That queue is
held in memory with no `storage` extension, so queued batches are lost when
the pod is replaced. The role does not change queue size or timeouts: nothing
from the incident shows a larger queue would have helped, since the queue
filled because ClickHouse inserts were timing out. A persistent queue would
need a `file_storage` extension and a volume for the collector, which is a
separate change.

## Checkmk checks (independent of SigNoz)

Both are agent local checks, so they notify through Checkmk even when SigNoz
or its collector is down.

`check_signoz_ingestion.sh` on `signoz_checkmk_monitor_host` reports two
services:

| Service | State |
| --- | --- |
| SigNoz log ingestion | OK under 60 s, WARN from 60 s, CRIT from 300 s since the newest log; CRIT if there are no logs in the last hour, the table is empty, or ClickHouse returns an error; UNKNOWN if kubectl, the pod lookup or the 20 s time limit fails |
| SigNoz log exporter | CRIT on `sending queue is full`, `PrepareBatch … context deadline exceeded`, `Exporting failed. Dropping data` or `Rejecting data` in any collector pod's log in the last 5 min |

The freshness query only reads the last hour (it filters on the `logs_v2`
primary key `ts_bucket_start` and the partition key). It runs as
`signoz_checkmk`, a ClickHouse user created through the chart's `users.d`
files. That user has no password but only accepts connections from inside the
ClickHouse pod. It can `SELECT` only `timestamp` and `ts_bucket_start` from
`signoz_logs.logs_v2`, cannot write, and cannot raise its 20 s limit. Adding
the user does not restart ClickHouse.

`check_signoz_clickhouse_disk.sh` on `signoz_clickhouse_local_storage_node`
watches `/var/lib/clickhouse`: WARN at 75%, CRIT at 85%, each only after
usage has stayed at that level for 300 s. It reports CRIT if the path is not
its own mount, rather than checking the parent filesystem.

## Storage

The production PV and PVC declare `450Gi` (there is no 750 GiB value in this
repository). The XFS filesystem behind it on k8s-prod4 is 950 GiB. The value is
deliberately left as it is:

- a local PV's capacity is a scheduling label; Kubernetes neither enforces it
  nor resizes the filesystem, so ClickHouse can already use all 950 GiB;
- the StorageClass has `allowVolumeExpansion: false`, so a larger PVC request
  would be rejected, and the role's PVC checks expect the value unchanged.

Growing the filesystem is a host operation (LVM/XFS) and is not done here. The
Checkmk disk check measures the real filesystem.

## Rollout

1. Check mode first: `ansible-playbook playbooks/signoz.yml -e runtime_env=production --check --diff`.
   Review the planned TTL changes and the deferred tables.
2. Run the playbook. It aligns TTLs, upgrades the chart (operator config, the
   `signoz_checkmk` user, collector telemetry), and installs the Checkmk
   checks. Expect:
   - the **collector pod to restart** (its ConfigMap changes), so log
     ingestion pauses briefly;
   - the ClickHouse operator pod to restart, and ClickHouse not to restart.
3. Rediscover services on k8s-prod1 and k8s-prod4 in Checkmk: there is a new
   **SigNoz log exporter** service and a new **ClickHouse data filesystem**
   service.
4. After storing an API key in the vault and naming the existing channels,
   set `signoz_alert_rules_enabled: true` and run again.
5. At the next planned ClickHouse restart, check for `_N` tables (query above).

## Verification

```bash
NS=platform; CH=chi-signoz-clickhouse-cluster-0-0-0
ch() { microk8s kubectl -n $NS exec $CH -c clickhouse -- clickhouse-client -q "$1"; }

# TTLs
ch "SELECT name, extract(engine_full, 'TTL (.*?) SETTINGS') FROM system.tables
    WHERE database = 'system' AND name LIKE '%_log' ORDER BY name"
# No TTL rewrites were queued
ch "SELECT count() FROM system.mutations WHERE database = 'system' AND NOT is_done"
# Config files are in the pod
microk8s kubectl -n $NS exec $CH -c clickhouse -- ls /etc/clickhouse-server/conf.d /etc/clickhouse-server/users.d

# Log timestamps keep advancing: run twice a minute apart, lag stays small
ch "SELECT dateDiff('second', toDateTime(intDiv(max(timestamp), 1000000000)), now())
    FROM signoz_logs.logs_v2
    WHERE ts_bucket_start >= toUInt64(toUnixTimestamp(now()) - 5400)"

# Exporter failures have stopped
microk8s kubectl -n $NS logs deploy/signoz-otel-collector -c collector --since=10m \
  | grep -Eic 'sending queue is full|context deadline exceeded|Dropping data'

# Checkmk checks
/usr/lib/check_mk_agent/local/check_signoz_ingestion.sh            # on k8s-prod1
/usr/lib/check_mk_agent/local/check_signoz_clickhouse_disk.sh      # on k8s-prod4
```

In SigNoz, the metric `otelcol_exporter_queue_capacity` should appear within a
minute of the collector restart, and its `exporter` label should include
`clickhouselogsexporter`.

## Rollback

- Retention: set `signoz_clickhouse_system_log_retention_days` (or overrides)
  back to the old value and run the role. It applies the new value in both the
  configuration and the live tables. Records already deleted do not come back.
- Collector telemetry: set `signoz_otel_internal_metrics_enabled: false`
  (restarts the collector again).
- Checkmk: set `signoz_checkmk_clickhouse_disk_enabled: false` and delete the
  installed script; the ingestion check reverts with the template.
- Alerts: set `signoz_alert_rules_enabled: false`; the role then leaves the
  rules alone, and you delete them in the SigNoz UI.
- The `signoz_checkmk` user goes away when its file is removed from the
  values template.

## Testing

`molecule test` in this role runs the migration, the values template, the
alert management and the Checkmk checks against stand-ins for
`clickhouse-client`, `kubectl` and the SigNoz API. It covers check mode,
idempotence, per-table overrides, refusal of unrecognised TTLs, a missing
pod, ClickHouse being down, and every Checkmk state.

## Dependencies

None.

## Example Playbook

The role is intended to be run on a [microk8s](../microk8s_cluster/) host. Below is a minimal playbook:

```yaml

- name: Deploy SigNoz on microk8s
  hosts: microk8s_hosts
  become: yes
  roles:
  - signoz_k8s
```
