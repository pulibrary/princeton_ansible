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
ClickHouse pod. It can `SELECT` only `timestamp`, `ts_bucket_start` and
`observed_timestamp` from `signoz_logs.logs_v2` (the last one is read by the
collector watchdog below), cannot write, and cannot raise its 20 s limit.
Adding the user or changing its grant does not restart ClickHouse.

`check_signoz_clickhouse_disk.sh` on `signoz_clickhouse_local_storage_node`
watches `/var/lib/clickhouse`: WARN at 75%, CRIT at 85%, each only after
usage has stayed at that level for 300 s. It reports CRIT if the path is not
its own mount, rather than checking the parent filesystem.

## Collector recovery watchdog (temporary)

Production SigNoz has repeatedly stopped storing logs while the collector pod
stayed `1/1 Running` with no container restarts. The collector logged
`couldn't PrepareBatch for inserting resource fingerprints :context deadline
exceeded`, then `sending queue is full`, retry exhaustion and dropped batches.
ClickHouse recorded an incomplete log INSERT (`ATTEMPT_TO_READ_AFTER_EOF`) as
the latest outage began, with 309 GB free. The HTTP liveness and readiness
probes did not notice. Each time, restarting only the collector restored
ingestion.

**The cause is not known. The watchdog automates that restart under strict
limits. It does not fix the defect.** Remove it once the cause is fixed.

### What it does

A systemd timer on one host, `signoz_collector_watchdog_host`, runs
`signoz-collector-watchdog check` once a minute. Production uses
`k8s-prod1.lib.princeton.edu`, the primary control-plane node that already
runs the ingestion check. Only that host gets it; the role removes it from
every other host in the play.

Each check:

1. Takes a lock (`/var/lib/signoz-collector-watchdog/watchdog.lock`); if
   another run holds it, the check exits with status 75 and changes nothing.
2. Measures ingestion age with ClickHouse's clock, as the `signoz_checkmk`
   user:

   ```sql
   SELECT toUnixTimestamp(now('UTC')) AS now_s, count() AS window_rows,
          max(observed_timestamp) AS newest_ns, ...
   FROM signoz_logs.logs_v2
   WHERE ts_bucket_start >= toUInt64(toUnixTimestamp(now()) - 3600 - 1800)
     AND timestamp >= toUInt64(toUnixTimestamp(now()) - 3600) * 1000000000
   FORMAT JSONEachRow
   ```

   The filters use the primary key and the partition key, as the Checkmk
   ingestion check does. On ClickHouse 25.12.5.44 with 52 M synthetic rows
   over 30 days, this read 14 of 6,331 granules (108 K rows, 2.5 MiB). The
   same `max(observed_timestamp)` without a filter read all 52 M rows
   (396 MiB).

   The filter cannot hide a long outage. If the last hour has no rows, the
   watchdog runs `SELECT count() FROM signoz_logs.logs_v2`, which ClickHouse
   answers from part metadata without reading data. A non-empty table is
   then reported as stale, "no logs observed in the last 3600 s" (a lower
   bound on the age). An empty table is reported as an error.
3. Treats these as failures that never trigger a restart: a query error,
   a timeout, an empty table, output that is not exactly one JSON row with
   numeric fields, and a newest record more than 120 s in the future (it
   would keep `max()` ahead of the clock and hide a stall). A failure also
   resets the stale streak, so the stale checks that trigger a restart must
   be consecutive successful queries.
4. Counts a check as stale when the newest record is at least
   `signoz_collector_watchdog_stale_seconds` (300) old. Only after
   `signoz_collector_watchdog_stale_checks` (2) consecutive stale checks does
   it consider a restart, and only if all of these hold:
   - no maintenance inhibit is active;
   - the circuit breaker is closed;
   - the last attempt was at least `cooldown_seconds` (1800) ago;
   - fewer than `max_restarts` (2) attempts were made in the last
     `restart_window_seconds` (3600);
   - `deployment/signoz-otel-collector` exists, wants more than 0 replicas,
     is not paused, and has no rollout in progress. This is the same test
     `kubectl rollout status` uses: `observedGeneration` has caught up with
     `generation`, every replica is updated and available, no old replicas
     remain, and the deadline has not been exceeded. The pod's `Running`
     phase is not used.
5. Records the attempt in the state file **before** acting, so it counts
   against cooldown and budget even if the run dies part-way.
6. Saves evidence (below), then runs `kubectl rollout restart
   deployment/signoz-otel-collector`. It never deletes pods and never touches
   ClickHouse, ZooKeeper, MicroK8s or the host.
7. Waits up to `rollout_timeout_seconds` (300) for `kubectl rollout status`.
   A finished rollout is not counted as recovery. For up to
   `verify_timeout_seconds` (300) it polls every 15 s until the newest
   `observed_timestamp` is **later than before the restart** and also
   **younger than the stale threshold**.
8. If the restart command, the rollout or the verification fails, it opens
   the **circuit breaker**. There are no more automatic restarts until an
   operator resets it, even if ingestion recovers by itself.

The timer only schedules checks. A restart happens only after confirmed
staleness; there are no scheduled restarts.

### Assumptions and risks

- **Production normally receives logs every few seconds.** A real lull of
  five minutes or more would look like a stall and cause one restart (and,
  if logs do not arrive within the verification time, an open circuit
  breaker). Staging can be quiet, which is why it stays disabled there.
- The window filters on event time (`timestamp`) and measures receive time
  (`observed_timestamp`). If all records arriving carried event times more
  than an hour old, ingestion would look stale.
- The collector's sending queue is in memory. **Batches queued at the moment
  of the restart are lost**. Logs dropped before the restart are also not
  recovered; this only shortens the outage.
- A restart can hide the conditions an investigation needs. That is why
  evidence is captured first and why repeated failures stop at the circuit
  breaker.
- The collector's liveness probe is unchanged. It is not tied to ClickHouse
  availability.

### Variables

| Variable | Default | Meaning |
| --- | --- | --- |
| `signoz_collector_watchdog_enabled` | `false` | Install and run it (production: `true`). |
| `signoz_collector_watchdog_host` | `""` | The one host that runs it (production: `k8s-prod1.lib.princeton.edu`). Must be in the play. |
| `signoz_collector_watchdog_restart_enabled` | `true` | `false` = detect and report only. |
| `signoz_collector_watchdog_stale_seconds` | `300` | Age at which a check is stale. |
| `signoz_collector_watchdog_stale_checks` | `2` | Consecutive stale checks before a restart. |
| `signoz_collector_watchdog_cooldown_seconds` | `1800` | Minimum time between attempts. |
| `signoz_collector_watchdog_max_restarts` | `2` | Attempts allowed per window. |
| `signoz_collector_watchdog_restart_window_seconds` | `3600` | Rolling window for the budget. |
| `signoz_collector_watchdog_lookback_seconds` | `3600` | Query window (see above). |
| `signoz_collector_watchdog_future_tolerance_seconds` | `120` | Clock skew accepted before a future timestamp is an error. |
| `signoz_collector_watchdog_query_timeout_seconds` | `signoz_checkmk_command_timeout_seconds` (20) | ClickHouse query limit; the user's profile caps it there anyway. |
| `signoz_collector_watchdog_kubectl_timeout_seconds` | `30` | Limit for each other kubectl call. |
| `signoz_collector_watchdog_rollout_timeout_seconds` | `300` | Wait for the rollout. |
| `signoz_collector_watchdog_verify_timeout_seconds` | `300` | Wait for fresh, advancing logs. |
| `signoz_collector_watchdog_verify_interval_seconds` | `15` | Poll interval while verifying. |
| `signoz_collector_watchdog_state_dir` | `/var/lib/signoz-collector-watchdog` | State, lock, inhibit and incidents. |
| `signoz_collector_watchdog_evidence_timeout_seconds` | `60` | Total time allowed for evidence capture. |
| `signoz_collector_watchdog_evidence_log_since` | `15m` | Collector log window captured. |
| `signoz_collector_watchdog_evidence_log_max_bytes` | `5242880` | Log bytes kept per collector pod. |
| `signoz_collector_watchdog_incident_keep` | `20` | Incident directories kept. |
| `signoz_collector_watchdog_incident_max_age_days` | `30` | Incident directories older than this are deleted. |
| `signoz_collector_watchdog_inhibit_max_seconds` | `604800` | Longest maintenance inhibit. |
| `signoz_collector_watchdog_checkmk_stale_seconds` | `300` | Checkmk CRIT when the last check is older. |
| `signoz_collector_watchdog_checkmk_recent_restart_seconds` | `3600` | Checkmk WARN this long after a restart. |

Installed files: `/usr/local/sbin/signoz-collector-watchdog`,
`/etc/signoz/collector-watchdog.json`,
`/etc/systemd/system/signoz-collector-watchdog.{service,timer}` and
`/usr/lib/check_mk_agent/local/check_signoz_collector_watchdog.sh`.

### Files and evidence

All under `/var/lib/signoz-collector-watchdog` (mode `0700`, files `0600`,
outside SigNoz and outside `/tmp`):

| Path | Contents |
| --- | --- |
| `state.json` | Last check time and status, stale streak, last observation, restart attempts and their results, circuit breaker. Written atomically (temporary file, `fsync`, rename). |
| `inhibit.json` | Active maintenance inhibit, if any. |
| `watchdog.lock` | `flock` lock against overlapping runs. |
| `incidents/<UTC time>/` | Evidence from one restart attempt. |

Each incident directory holds `watchdog.json` (the observation and the
Deployment status that led to the restart), `deployment.json`, `pods.txt`
(`get pods -o wide` for the namespace), `collector-pods.json`, `events.json`,
and `collector-<pod>.log` (the last 15 minutes, at most 5 MiB per pod). If any
step failed, it also has `capture-errors.txt`.

- The Deployment and pod JSON are reduced to names, images, resources,
  probes, placement and status. Environment variables are never written,
  because the pod template carries the ClickHouse password. Logs and other
  text pass through a filter that masks `user:password@` URLs and
  `password=`, `token=`, `api_key=` style values.
- Each kubectl call has a time limit, and capture as a whole stops after
  60 s. A capture failure is recorded in `capture-errors.txt` and in the
  attempt's `evidence_errors`, and the restart still goes ahead.
- After each run only the newest 20 incident directories are kept, and none
  older than 30 days.

### Checkmk

`check_signoz_collector_watchdog.sh` reports one service, **SigNoz collector
watchdog**. It reads only the state file, the inhibit file and the timer
state. It does not depend on SigNoz, so it still alerts when SigNoz cannot
store its own alerts.

| State | Meaning |
| --- | --- |
| OK | `healthy`: ingestion is fresh |
| WARN | `stale_pending` (first stale check), `inhibited` (maintenance), `recovering` (restart in progress), `recovered`, or healthy within an hour after an automatic restart; also any time the circuit breaker is open while ingestion is healthy |
| CRIT | `restart_blocked` (stale, but cooldown, budget, circuit breaker, rollout in progress, scaled to zero, missing Deployment or detect-only mode prevents a restart); `recovery_failed` (restart, rollout or verification failed); empty table or future timestamps; **last check more than 300 s ago or timer not active (watchdog not running)** |
| UNKNOWN | the ingestion query failed or timed out, the state or config cannot be read, or no check has run yet |

Metrics: `ingestion_age`, `consecutive_stale`, `restarts` (attempts in the
current window). The service text names the status, the reason and the
newest log time. The existing **SigNoz log ingestion** service stays the
independent signal that ingestion is stale.

After the first run with the watchdog enabled, **rediscover services on
k8s-prod1 in Checkmk and activate changes** so the new service is
monitored.

### Operating it

On the watchdog host, as root:

```bash
signoz-collector-watchdog status                 # state + inhibit as JSON
journalctl -u signoz-collector-watchdog.service  # one line per check
systemctl list-timers signoz-collector-watchdog.timer
/usr/lib/check_mk_agent/local/check_signoz_collector_watchdog.sh
```

**Maintenance** (ClickHouse upgrades, planned SigNoz downtime, chart
upgrades that may pause ingestion):

```bash
signoz-collector-watchdog inhibit --duration 2h --reason "ClickHouse upgrade CHG-123"
signoz-collector-watchdog uninhibit
```

While inhibited, checks still run and report, but restarts are suspended and
the stale streak is not counted. When the inhibit ends, two new stale checks
are needed. An inhibit expires by itself (at most 7 days). If the inhibit
file cannot be read, restarts stay suspended.

**Circuit breaker reset**, after investigating why a recovery failed:

```bash
signoz-collector-watchdog status       # failure_reason, restart_attempts, incident path
signoz-collector-watchdog reset        # close the breaker; cooldown and budget still apply
signoz-collector-watchdog reset --clear-history  # also forget past attempts
```

`reset` also replaces an unreadable state file, keeping it as
`state.json.corrupt.<time>`. While the state file is unreadable the
watchdog does nothing.

**Manual recovery** (what the watchdog would do):

```bash
signoz-collector-watchdog inhibit --duration 1h --reason "manual recovery"
microk8s kubectl -n platform rollout restart deployment/signoz-otel-collector
microk8s kubectl -n platform rollout status deployment/signoz-otel-collector --timeout=5m
# then confirm the ingestion check age falls and keeps falling
/usr/lib/check_mk_agent/local/check_signoz_ingestion.sh
signoz-collector-watchdog uninhibit
```

**Detect-only mode**: set `signoz_collector_watchdog_restart_enabled: false`.
Stale ingestion then shows as `restart_blocked: restart_disabled` (CRIT).

### Staging validation

Staging is disabled by default because it can be legitimately quiet. To
validate there without touching production:

1. Run the playbook for staging with the watchdog in detect-only mode:
   `ansible-playbook playbooks/signoz.yml -e runtime_env=staging
   -e signoz_collector_watchdog_enabled=true
   -e signoz_collector_watchdog_restart_enabled=false`.
   The same run applies the `observed_timestamp` grant. Check that it did
   not restart ClickHouse (`RESTARTS` and `AGE` of
   `chi-signoz-clickhouse-cluster-0-0-0`).
2. On k8s-staging1, check the query and its cost:
   `signoz-collector-watchdog check`, then `EXPLAIN indexes = 1` of the
   window query (in `/usr/local/sbin/signoz-collector-watchdog`), which
   should select a small fraction of the parts and granules.
3. Simulate stale ingestion **without stopping anything** by making the
   threshold smaller than the normal lag. Edit
   `/etc/signoz/collector-watchdog.json` to `"stale_seconds": 1`; two checks
   later the state is `restart_blocked: restart_disabled` and Checkmk is
   CRIT. Put the file back (or re-run the playbook).
4. To exercise a real restart once, set `"restart_enabled": true` in the
   same file with `"stale_seconds": 1`. The watchdog captures evidence,
   restarts the collector, and then fails verification because the age
   never goes below 1 s. That opens the circuit breaker, which is also worth
   seeing. Inspect the incident directory (no credentials, sizes bounded),
   then run `signoz-collector-watchdog reset --clear-history` and re-run the
   playbook.
5. Test `inhibit`/`uninhibit` and stop the timer
   (`systemctl stop signoz-collector-watchdog.timer`) to see the Checkmk
   "not active" and, five minutes later, "not running" states.

### Disabling and rollback

- Set `signoz_collector_watchdog_enabled: false` and run the playbook. The
  timer is stopped and the program, configuration, units and Checkmk check
  are removed. `/var/lib/signoz-collector-watchdog` (state and evidence) is
  left for review; delete it by hand when no longer needed. Remove the
  Checkmk service by rediscovering the host.
- To stop it immediately without Ansible: `systemctl disable --now
  signoz-collector-watchdog.timer` (Checkmk then reports it CRIT as not
  running, which is intended).
- The `observed_timestamp` grant can stay; it is read-only.

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
   service. With the collector watchdog enabled, k8s-prod1 also has a new
   **SigNoz collector watchdog** service.
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
pod, ClickHouse being down, and every Checkmk state. It also installs the
collector watchdog, runs one check through systemd, runs the watchdog unit
tests on the instance's Python, and disables it again.

The watchdog's unit tests need no cluster and run on a workstation:

```bash
python3 -m unittest discover -s roles/signoz_k8s/tests/collector_watchdog -v
```

They use `tests/collector_watchdog/fake_microk8s.py` for kubectl and
ClickHouse and cover healthy and stale ingestion, the consecutive-check
rule, query failures and timeouts, empty, malformed and future results,
rollouts in progress, scale-to-zero, a missing Deployment, maintenance
inhibit, lock contention, cooldown and the rolling budget, failed restarts,
rollouts and verification, persistent and corrupt state, evidence redaction,
size and time limits, incident retention, and every Checkmk state.

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
