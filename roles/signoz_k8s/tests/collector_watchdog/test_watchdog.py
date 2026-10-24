"""Tests for files/signoz-collector-watchdog with a fake microk8s.

Run from the repository root:
  python3 -m unittest discover -s roles/signoz_k8s/tests/collector_watchdog -v

Nothing here talks to a cluster: kubectl and clickhouse-client are answered
by fake_microk8s.py from a per-test scenario file.
"""
import fcntl
import json
import os
import stat
import subprocess
import sys
import tempfile
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
WATCHDOG = os.path.join(HERE, "..", "..", "files", "signoz-collector-watchdog")
FAKE = os.path.join(HERE, "fake_microk8s.py")

CH_NOW = 1_800_000_000  # ClickHouse clock used by the fake rows
T0 = 1_800_000_000.0  # local clock (SIGNOZ_WATCHDOG_NOW)


def window(age=None, rows=100, now_s=CH_NOW):
    """A freshness query result whose newest record is age seconds old."""
    if age is None:
        row = {"now_s": now_s, "current_utc": "x", "window_rows": "0", "newest_ns": "0",
               "newest_observed_utc": "1970-01-01 00:00:00"}
    else:
        row = {"now_s": now_s, "current_utc": "x", "window_rows": str(rows),
               "newest_ns": str((now_s - age) * 1_000_000_000 + 123),
               "newest_observed_utc": "t-%d" % age}
    return {"stdout": json.dumps(row) + "\n"}


def deployment(replicas=1, generation=5, observed=5, updated=1, total=1, available=1, **extra):
    dep = {
        "metadata": {"name": "signoz-otel-collector", "namespace": "platform", "generation": generation,
                     "annotations": {"kubectl.kubernetes.io/last-applied-configuration": "{secret}"}},
        "spec": {
            "replicas": replicas,
            "selector": {"matchLabels": {"app.kubernetes.io/component": "otel-collector"}},
            "template": {"spec": {"containers": [{
                "name": "collector", "image": "signoz/signoz-otel-collector:v0.144.14",
                "env": [{"name": "CLICKHOUSE_PASSWORD", "value": "hunter2"}],
            }]}},
        },
        "status": {"observedGeneration": observed, "updatedReplicas": updated, "replicas": total,
                   "availableReplicas": available},
    }
    dep["spec"].update(extra)
    return {"stdout": json.dumps(dep)}


PODS = {"stdout": json.dumps({"items": [{
    "metadata": {"name": "signoz-otel-collector-abc"},
    "spec": {"nodeName": "k8s-prod3", "containers": [{"env": [{"name": "X", "value": "hunter2"}]}]},
    "status": {"phase": "Running", "containerStatuses": [{"name": "collector", "restartCount": 0}]},
}]})}
LOGS = {"stdout": "2026-10-24T03:37:01Z error couldn't PrepareBatch: context deadline exceeded "
                  "dsn=tcp://admin:hunter2@signoz-clickhouse:9000 password=hunter2\n"}


class WatchdogTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = self.tmp.name
        self.state_dir = os.path.join(self.dir, "state")
        self.scenario = os.path.join(self.dir, "scenario.json")
        self.calls_file = os.path.join(self.dir, "calls.jsonl")
        self.config_path = os.path.join(self.dir, "config.json")
        self.config = {
            "microk8s": FAKE,
            "state_dir": self.state_dir,
            "query_timeout_seconds": 1,
            "kubectl_timeout_seconds": 2,
            "rollout_timeout_seconds": 2,
            "verify_timeout_seconds": 0.3,
            "verify_interval_seconds": 0.05,
            "evidence_timeout_seconds": 10,
            "incident_keep": 3,
            "incident_max_age_days": 30,
        }
        self.write_config()
        self.set_scenario({"window": window(5)})
        self.clock = T0

    def tearDown(self):
        self.tmp.cleanup()

    def write_config(self, **overrides):
        self.config.update(overrides)
        with open(self.config_path, "w") as f:
            json.dump(self.config, f)

    def set_scenario(self, scenario):
        base = {"deployment": deployment(), "pods_wide": {"stdout": "NAME READY\n"}, "pods_json": PODS,
                "events": {"stdout": json.dumps({"items": []})}, "logs": LOGS,
                "rollout_restart": {"stdout": "restarted\n"},
                "rollout_status": {"stdout": "successfully rolled out\n"}}
        base.update(scenario)
        with open(self.scenario, "w") as f:
            json.dump(base, f)
        open(self.calls_file, "w").close()

    def run_watchdog(self, *args, at=None, env=None):
        environ = dict(os.environ, FAKE_K8S_SCENARIO=self.scenario, FAKE_K8S_CALLS=self.calls_file,
                       SIGNOZ_WATCHDOG_NOW=str(self.clock if at is None else at),
                       SIGNOZ_WATCHDOG_SKIP_TIMER_CHECK="1")
        environ.update(env or {})
        return subprocess.run([sys.executable, WATCHDOG, "--config", self.config_path] + list(args),
                              capture_output=True, text=True, env=environ, timeout=60)

    def check(self, at=None):
        return self.run_watchdog("check", at=at)

    def checkmk(self, at=None):
        out = self.run_watchdog("checkmk", at=at).stdout.strip()
        self.assertTrue(out.startswith(("0 ", "1 ", "2 ", "3 ")), out)
        self.assertIn('"SigNoz collector watchdog"', out)
        return int(out[0]), out

    def state(self):
        with open(os.path.join(self.state_dir, "state.json")) as f:
            return json.load(f)

    def calls(self):
        with open(self.calls_file) as f:
            return [json.loads(line) for line in f]

    def restarts(self):
        return [c for c in self.calls() if "rollout" in c and "restart" in c]

    def tick(self, seconds=60):
        self.clock += seconds

    # ---- detection ----------------------------------------------------

    def test_healthy_ingestion(self):
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        state = self.state()
        self.assertEqual(state["status"], "healthy")
        self.assertEqual(state["last_observation"]["age_seconds"], 5)
        self.assertEqual(state["last_check"], T0)
        self.assertEqual(self.checkmk()[0], 0)
        # Healthy runs only query ClickHouse.
        self.assertEqual([c for c in self.calls() if "exec" not in c], [])

    def test_query_is_bounded_and_uses_clickhouse_clock(self):
        self.check()
        query = self.calls()[0][self.calls()[0].index("--query") + 1]
        self.assertIn("now('UTC')", query)
        self.assertIn("max(observed_timestamp)", query)
        self.assertIn("ts_bucket_start >=", query)
        self.assertIn("FORMAT JSONEachRow", query)
        self.assertIn("--user", self.calls()[0])

    def test_one_stale_check_does_not_restart(self):
        self.set_scenario({"window": window(400)})
        self.assertEqual(self.check().returncode, 0)
        self.assertEqual(self.state()["status"], "stale_pending")
        self.assertEqual(self.state()["consecutive_stale"], 1)
        self.assertEqual(self.restarts(), [])
        self.assertEqual(self.checkmk()[0], 1)

    def test_two_consecutive_stale_checks_restart_and_recover(self):
        self.set_scenario({"window": [window(400), window(460), window(3)]})
        self.check()
        self.tick()
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stdout)
        state = self.state()
        self.assertEqual(state["status"], "recovered", state)
        self.assertEqual(len(self.restarts()), 1)
        self.assertEqual(self.restarts()[0][-1], "deployment/signoz-otel-collector")
        self.assertEqual(state["restart_attempts"][-1]["result"], "recovered")
        self.assertEqual(state["consecutive_stale"], 0)
        self.assertFalse(state["circuit_open"])
        # Rollout status is waited for before verification.
        verbs = [c[c.index("rollout") + 1] for c in self.calls() if "rollout" in c]
        self.assertEqual(verbs, ["restart", "status"])
        level, line = self.checkmk()
        self.assertEqual(level, 1, line)
        self.assertIn("recovered", line)
        # After an hour the restart notice clears.
        self.set_scenario({"window": window(2)})
        self.tick(3601)
        self.check()
        self.assertEqual(self.checkmk()[0], 0)

    def test_stale_streak_resets_on_fresh_result(self):
        self.set_scenario({"window": [window(400), window(10), window(400)]})
        self.check()
        self.check()
        self.check()
        self.assertEqual(self.state()["consecutive_stale"], 1)
        self.assertEqual(self.restarts(), [])

    def test_query_failure_is_reported_and_never_restarts(self):
        self.set_scenario({"window": [window(400), {"rc": 210, "stderr":
                          "Code: 210. DB::NetException: Connection refused (localhost:9000)\n"}, window(400)]})
        self.check()
        result = self.check()
        self.assertEqual(result.returncode, 1)
        state = self.state()
        self.assertEqual(state["status"], "query_error")
        self.assertEqual(state["error_kind"], "clickhouse")
        self.assertIn("Connection refused", state["detail"])
        self.assertEqual(self.checkmk()[0], 3)
        # The failure broke the streak: the next stale result is only #1.
        self.check()
        self.assertEqual(self.state()["consecutive_stale"], 1)
        self.assertEqual(self.restarts(), [])

    def test_kubectl_failure(self):
        self.set_scenario({"window": {"rc": 1, "stderr": "error: unable to upgrade connection\n"}})
        self.assertEqual(self.check().returncode, 1)
        self.assertEqual(self.state()["error_kind"], "kubectl")

    def test_query_timeout(self):
        self.set_scenario({"window": dict(window(400), sleep=30)})
        started = time.monotonic()
        result = self.check()
        self.assertLess(time.monotonic() - started, 20)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.state()["error_kind"], "timeout")
        self.assertEqual(self.restarts(), [])

    def test_empty_table(self):
        self.set_scenario({"window": window(None), "total": {"stdout": '{"now_s":1,"total_rows":"0"}\n'}})
        self.assertEqual(self.check().returncode, 1)
        self.assertEqual(self.state()["error_kind"], "empty_table")
        self.assertEqual(self.checkmk()[0], 2)

    def test_malformed_results(self):
        for output in ["garbage\n", "", '{"now_s": 1}\n', '{"now_s":1,"window_rows":"x"}\n',
                       window(5)["stdout"] * 2, "[1,2]\n",
                       '{"now_s":1800000000,"window_rows":"5","newest_ns":"0"}\n']:
            with self.subTest(output=output):
                self.set_scenario({"window": {"stdout": output}})
                self.assertEqual(self.check().returncode, 1)
                self.assertEqual(self.state()["error_kind"], "malformed")
                self.assertEqual(self.checkmk()[0], 3)

    def test_future_timestamp_is_an_error(self):
        self.set_scenario({"window": window(-600)})
        self.assertEqual(self.check().returncode, 1)
        self.assertEqual(self.state()["error_kind"], "future_timestamp")
        self.assertEqual(self.checkmk()[0], 2)
        # Small skew within tolerance counts as fresh.
        self.set_scenario({"window": window(-30)})
        self.check()
        self.assertEqual(self.state()["status"], "healthy")
        self.assertEqual(self.state()["last_observation"]["age_seconds"], 0)

    def test_window_empty_but_table_not_is_stale_without_full_scan(self):
        self.set_scenario({"window": [window(None), window(None), window(3)],
                           "total": {"stdout": '{"now_s":1,"total_rows":"12345"}\n'}})
        self.check()
        state = self.state()
        self.assertEqual(state["status"], "stale_pending")
        self.assertTrue(state["last_observation"]["age_lower_bound"])
        self.assertIn("no logs observed in the last 3600s", state["detail"])
        self.check()
        self.assertEqual(self.state()["status"], "recovered")
        total_query = [c for c in self.calls() if "exec" in c and "total_rows" in c[-1]][0][-1]
        self.assertNotIn("WHERE", total_query)
        self.assertNotIn("observed_timestamp", total_query)

    # ---- guards --------------------------------------------------------

    def stale_twice(self, **scenario):
        self.set_scenario(dict({"window": window(400)}, **scenario))
        self.check()
        self.tick()
        return self.check()

    def test_rollout_in_progress_blocks(self):
        for dep in [deployment(observed=4), deployment(updated=0), deployment(total=2),
                    deployment(available=0), deployment(paused=True)]:
            with self.subTest(dep=dep):
                self.tearDown(); self.setUp()
                self.stale_twice(deployment=dep)
                self.assertEqual(self.state()["status"], "restart_blocked")
                self.assertIn(self.state()["block_reason"], ("rollout_in_progress", "rollout_paused"))
                self.assertEqual(self.restarts(), [])
                self.assertEqual(self.checkmk()[0], 2)

    def test_scaled_to_zero_blocks(self):
        self.stale_twice(deployment=deployment(replicas=0, updated=0, total=0, available=0))
        self.assertEqual(self.state()["block_reason"], "scaled_to_zero")
        self.assertEqual(self.restarts(), [])

    def test_missing_deployment_blocks(self):
        self.stale_twice(deployment={"rc": 1, "stderr":
                                     'Error from server (NotFound): deployments.apps "signoz-otel-collector" not found\n'})
        self.assertEqual(self.state()["block_reason"], "deployment_missing")
        self.assertEqual(self.restarts(), [])

    def test_restart_disabled_detects_only(self):
        self.write_config(restart_enabled=False)
        self.stale_twice()
        self.assertEqual(self.state()["block_reason"], "restart_disabled")
        self.assertEqual(self.restarts(), [])

    def test_maintenance_inhibit(self):
        result = self.run_watchdog("inhibit", "--duration", "2h", "--reason", "ClickHouse upgrade")
        self.assertEqual(result.returncode, 0, result.stdout)
        inhibit_path = os.path.join(self.state_dir, "inhibit.json")
        self.assertEqual(stat.S_IMODE(os.stat(inhibit_path).st_mode), 0o600)
        self.set_scenario({"window": window(400)})
        for _ in range(3):
            self.check()
            self.tick()
        self.assertEqual(self.state()["status"], "inhibited")
        self.assertEqual(self.state()["consecutive_stale"], 0)
        self.assertEqual(self.restarts(), [])
        level, line = self.checkmk()
        self.assertEqual(level, 1)
        self.assertIn("ClickHouse upgrade", line)
        # Once it expires, two new stale checks are needed.
        self.clock = T0 + 7201
        self.check()
        self.assertEqual(self.state()["status"], "stale_pending")
        self.tick()
        self.check()
        self.assertEqual(len(self.restarts()), 1)

    def test_uninhibit_and_limits(self):
        self.assertEqual(self.run_watchdog("inhibit", "--duration", "30d", "--reason", "x").returncode, 2)
        self.run_watchdog("inhibit", "--duration", "1h", "--reason", "x")
        self.run_watchdog("uninhibit")
        self.stale_twice()
        self.assertEqual(len(self.restarts()), 1)

    def test_unreadable_inhibit_still_inhibits(self):
        os.makedirs(self.state_dir)
        with open(os.path.join(self.state_dir, "inhibit.json"), "w") as f:
            f.write("{oops")
        self.stale_twice()
        self.assertEqual(self.state()["status"], "inhibited")

    def test_lock_contention(self):
        self.check()
        before = self.state()
        lock = open(os.path.join(self.state_dir, "watchdog.lock"), "w")
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            self.set_scenario({"window": window(400)})
            result = self.check(at=T0 + 60)
        finally:
            lock.close()
        self.assertEqual(result.returncode, 75)
        self.assertEqual(self.state(), before)
        self.assertEqual(self.calls(), [])

    def test_cooldown(self):
        self.set_scenario({"window": [window(400), window(400), window(3), window(400)]})
        self.check()
        self.tick()
        self.check()
        self.assertEqual(len(self.restarts()), 1)
        for _ in range(2):
            self.tick(600)
            self.check()
        self.assertEqual(self.state()["block_reason"], "cooldown")
        self.assertEqual(len(self.restarts()), 1)
        self.assertEqual(self.checkmk()[0], 2)
        # Cooldown is 1800 s from the attempt.
        self.clock = T0 + 60 + 1800
        self.set_scenario({"window": [window(400), window(3)]})
        self.check()
        self.assertEqual(len(self.restarts()), 1)
        self.assertEqual(self.state()["status"], "recovered")

    def test_rolling_restart_budget(self):
        self.write_config(cooldown_seconds=0)
        self.set_scenario({"window": [window(400), window(400), window(3)] * 2 + [window(400)]})
        for _ in range(6):
            self.check()
            self.tick()
        self.assertEqual(len(self.restarts()), 2)
        self.assertEqual(self.state()["block_reason"], "restart_budget")
        self.assertEqual(self.checkmk()[0], 2)
        # The first attempt (at T0 + 60) leaves the one-hour window.
        self.clock = T0 + 60 + 3601
        self.set_scenario({"window": [window(400), window(3)]})
        self.check()
        self.assertEqual(len(self.restarts()), 1)

    # ---- recovery failures --------------------------------------------

    def test_failed_restart_opens_circuit(self):
        result = self.stale_twice(rollout_restart={"rc": 1, "stderr": "error: forbidden\n"})
        self.assertEqual(result.returncode, 1)
        state = self.state()
        self.assertEqual(state["status"], "recovery_failed")
        self.assertEqual(state["failure_reason"], "restart_failed")
        self.assertTrue(state["circuit_open"])
        # The failed attempt still counts.
        self.assertEqual(state["restart_attempts"][-1]["result"], "restart_failed")
        self.assertEqual(self.checkmk()[0], 2)
        # No further restarts until reset, even after cooldown.
        self.clock += 4000
        self.set_scenario({"window": window(400)})
        self.check(); self.tick(); self.check()
        self.assertEqual(self.state()["block_reason"], "circuit_open")
        self.assertEqual(self.restarts(), [])
        self.run_watchdog("reset")
        self.assertFalse(self.state()["circuit_open"])
        self.check(); self.tick(); self.check()
        self.assertEqual(len(self.restarts()), 1)

    def test_failed_rollout(self):
        self.stale_twice(rollout_status={"rc": 1, "stderr": "error: timed out waiting for the condition\n"})
        self.assertEqual(self.state()["failure_reason"], "rollout_failed")
        self.assertTrue(self.state()["circuit_open"])

    def test_verification_needs_advancing_timestamp(self):
        # Fresh by age (ClickHouse's clock stepped back) but the newest
        # record is the same one as before the restart.
        self.set_scenario({"window": [window(400), window(460), window(10, now_s=CH_NOW - 450)]})
        self.check(); self.tick(); self.check()
        state = self.state()
        self.assertEqual(state["failure_reason"], "verification_failed")
        self.assertIn("not newer", state["detail"])
        self.assertTrue(state["circuit_open"])

    def test_verification_needs_fresh_timestamp(self):
        # Advancing, but still older than the threshold.
        self.set_scenario({"window": [window(400), window(460), window(350)]})
        self.check(); self.tick(); self.check()
        self.assertEqual(self.state()["failure_reason"], "verification_failed")

    def test_verification_tolerates_transient_query_errors(self):
        self.set_scenario({"window": [window(400), window(460), {"rc": 1, "stderr": "Code: 210.\n"}, window(2)]})
        self.check(); self.tick(); self.check()
        self.assertEqual(self.state()["status"], "recovered")

    def test_verification_failure_when_queries_keep_failing(self):
        self.set_scenario({"window": [window(400), window(460), {"rc": 1, "stderr": "Code: 210.\n"}]})
        self.check(); self.tick(); self.check()
        self.assertEqual(self.state()["failure_reason"], "verification_failed")

    # ---- state and evidence -------------------------------------------

    def test_state_is_persistent_and_private(self):
        self.set_scenario({"window": window(400)})
        self.check()
        path = os.path.join(self.state_dir, "state.json")
        self.assertEqual(stat.S_IMODE(os.stat(path).st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(os.stat(self.state_dir).st_mode), 0o700)
        self.assertEqual(self.state()["consecutive_stale"], 1)
        self.assertEqual([n for n in os.listdir(self.state_dir) if ".tmp" in n], [])

    def test_corrupt_state_refuses_to_act(self):
        os.makedirs(self.state_dir)
        path = os.path.join(self.state_dir, "state.json")
        with open(path, "w") as f:
            f.write("{truncated")
        self.set_scenario({"window": window(400)})
        self.assertEqual(self.check().returncode, 1)
        self.assertEqual(self.calls(), [])
        self.assertEqual(self.checkmk()[0], 3)
        self.assertEqual(self.run_watchdog("reset").returncode, 0)
        self.assertTrue([n for n in os.listdir(self.state_dir) if ".corrupt." in n])
        self.check()
        self.assertEqual(self.state()["status"], "stale_pending")

    def test_evidence_capture(self):
        self.set_scenario({"window": [window(400), window(460), window(3)],
                           "logs": {"stdout": LOGS["stdout"] + "x" * 5000}})
        self.write_config(evidence_log_max_bytes=2000)
        self.check(); self.tick(); self.check()
        attempt = self.state()["restart_attempts"][-1]
        incident = attempt["incident"]
        self.assertEqual(attempt["evidence_errors"], [])
        self.assertEqual(stat.S_IMODE(os.stat(incident).st_mode), 0o700)
        names = sorted(os.listdir(incident))
        self.assertEqual(names, ["collector-pods.json", "collector-signoz-otel-collector-abc.log",
                                 "deployment.json", "events.json", "pods.txt", "watchdog.json"])
        everything = ""
        for name in names:
            path = os.path.join(incident, name)
            self.assertEqual(stat.S_IMODE(os.stat(path).st_mode), 0o600)
            with open(path) as f:
                everything += f.read()
        self.assertNotIn("hunter2", everything)
        self.assertNotIn("CLICKHOUSE_PASSWORD", everything)
        self.assertNotIn("last-applied-configuration", everything)
        self.assertIn("PrepareBatch", everything)
        log_size = os.path.getsize(os.path.join(incident, "collector-signoz-otel-collector-abc.log"))
        self.assertLess(log_size, 2100)
        # Logs are bounded on the kubectl side too.
        logs_call = [c for c in self.calls() if "logs" in c][0]
        self.assertIn("--limit-bytes=2000", logs_call)
        self.assertIn("--since=15m", logs_call)
        # The restart happens after the capture.
        keys = [c[c.index("-n") + 2] for c in self.calls() if "-n" in c]
        self.assertLess(keys.index("logs"), keys.index("rollout"))

    def test_evidence_failure_does_not_block_recovery(self):
        self.stale_twice(pods_wide={"rc": 1, "stderr": "boom\n"}, events={"stdout": "not json"},
                         pods_json={"rc": 1, "stderr": "boom\n"},
                         window=[window(400), window(460), window(3)])
        state = self.state()
        self.assertEqual(state["status"], "recovered")
        errors = state["restart_attempts"][-1]["evidence_errors"]
        self.assertEqual(len(errors), 3, errors)
        self.assertTrue(os.path.exists(os.path.join(state["restart_attempts"][-1]["incident"], "capture-errors.txt")))

    def test_evidence_time_limit(self):
        self.write_config(evidence_timeout_seconds=1)
        self.stale_twice(deployment=[deployment(), dict(deployment(), sleep=1.5)],
                         window=[window(400), window(460), window(3)])
        errors = self.state()["restart_attempts"][-1]["evidence_errors"]
        self.assertTrue(any("skipped" in e for e in errors), errors)
        self.assertEqual(len(self.restarts()), 1)

    def test_incident_retention(self):
        incidents = os.path.join(self.state_dir, "incidents")
        os.makedirs(incidents)
        old = ["20260101T000000Z", "20261001T000000Z", "20261002T000000Z", "20261003T000000Z",
               "20261004T000000Z", "not-an-incident"]
        for name in old:
            os.mkdir(os.path.join(incidents, name))
        at = 1_791_000_000  # 2026-10-03T03:20:00Z
        self.write_config(incident_keep=3, incident_max_age_days=30)
        self.check(at=at)
        left = sorted(os.listdir(incidents))
        # Count limit removes the oldest; the age limit removes the January one.
        self.assertEqual(left, ["20261002T000000Z", "20261003T000000Z", "20261004T000000Z", "not-an-incident"])
        self.write_config(incident_keep=10, incident_max_age_days=1)
        self.check(at=at)
        self.assertEqual(sorted(os.listdir(incidents)), ["20261003T000000Z", "20261004T000000Z", "not-an-incident"])

    # ---- Checkmk -------------------------------------------------------

    def test_checkmk_watchdog_not_running(self):
        self.check()
        self.assertEqual(self.checkmk(at=T0 + 299)[0], 0)
        level, line = self.checkmk(at=T0 + 301)
        self.assertEqual(level, 2)
        self.assertIn("not running", line)

    def test_checkmk_recovering_allows_long_runs(self):
        os.makedirs(self.state_dir)
        with open(os.path.join(self.state_dir, "state.json"), "w") as f:
            json.dump({"version": 1, "status": "recovering", "detail": "waiting for rollout",
                       "last_check": T0, "recovery_deadline": T0 + 900, "restart_attempts": []}, f)
        self.assertEqual(self.checkmk(at=T0 + 600)[0], 1)
        self.assertEqual(self.checkmk(at=T0 + 901)[0], 2)

    def test_checkmk_without_state_or_config(self):
        self.assertEqual(self.checkmk()[0], 3)
        out = subprocess.run([sys.executable, WATCHDOG, "--config", "/nonexistent", "checkmk"],
                             capture_output=True, text=True).stdout
        self.assertTrue(out.startswith('3 "SigNoz collector watchdog" - cannot read'), out)

    def test_invalid_config_is_refused(self):
        for bad in [{"stale_seconds": "300"}, {"restart_enabled": "false"}, {"max_restarts": -1}]:
            with self.subTest(bad=bad):
                self.write_config(**bad)
                result = self.check()
                self.assertEqual(result.returncode, 1)
                self.assertIn("cannot read", result.stdout)
                self.assertEqual(self.calls(), [])
                self.assertEqual(self.checkmk()[0], 3)
                self.config.update(stale_seconds=300, restart_enabled=True, max_restarts=2)

    def test_checkmk_timer_inactive(self):
        self.check()
        result = self.run_watchdog("checkmk", env={"SIGNOZ_WATCHDOG_SKIP_TIMER_CHECK": "",
                                                    "PATH": self.dir})
        self.assertTrue(result.stdout.startswith('2 "SigNoz collector watchdog"'), result.stdout)
        self.assertIn("not active", result.stdout)

    def test_checkmk_metrics(self):
        self.set_scenario({"window": window(400)})
        self.check()
        _, line = self.checkmk()
        self.assertIn(" ingestion_age=400;;300|consecutive_stale=1|restarts=0;;2 ", line)


if __name__ == "__main__":
    unittest.main()
