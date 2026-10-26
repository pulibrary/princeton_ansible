#!/usr/bin/env python3
"""Test stand-in for "microk8s kubectl" used by the collector watchdog.

Answers from a JSON scenario file named by FAKE_K8S_SCENARIO. Each key holds
a response {"rc", "stdout", "stderr", "sleep"} or a list of them; a list is
consumed in order and its last entry repeats. Every call is appended to
FAKE_K8S_CALLS as one JSON array per line.

Keys: window (watchdog freshness query), total (row count query),
deployment, pods_wide, pods_json, events, logs, rollout_restart,
rollout_status.
"""
import json
import os
import sys
import time


def key_for(args):
    if "exec" in args:
        query = args[args.index("--query") + 1]
        if "window_rows" in query:
            return "window"
        if "total_rows" in query:
            return "total"
        return "unknown_query"
    verb = args[0] if args else ""
    if verb == "get" and args[1] == "deployment":
        return "deployment"
    if verb == "get" and args[1] == "pods":
        return "pods_json" if "-l" in args else "pods_wide"
    if verb == "get" and args[1] == "events":
        return "events"
    if verb == "logs":
        return "logs"
    if verb == "rollout":
        return "rollout_" + args[1]
    return "unknown"


def main():
    argv = sys.argv[1:]
    assert argv[0] == "kubectl", argv
    args = [a for a in argv[1:] if not a.startswith("--request-timeout")]
    if args[:1] == ["-n"]:
        args = args[2:]
    with open(os.environ["FAKE_K8S_CALLS"], "a") as f:
        f.write(json.dumps(argv[1:]) + "\n")

    path = os.environ["FAKE_K8S_SCENARIO"]
    with open(path) as f:
        scenario = json.load(f)
    key = key_for(args)
    response = scenario.get(key, {"rc": 1, "stderr": "fake: no response for %s" % key})
    if isinstance(response, list):
        if len(response) > 1:
            scenario[key] = response[1:]
            with open(path + ".tmp", "w") as f:
                json.dump(scenario, f)
            os.replace(path + ".tmp", path)
        response = response[0]
    time.sleep(response.get("sleep", 0))
    sys.stdout.write(response.get("stdout", ""))
    sys.stderr.write(response.get("stderr", ""))
    return response.get("rc", 0)


if __name__ == "__main__":
    sys.exit(main())
