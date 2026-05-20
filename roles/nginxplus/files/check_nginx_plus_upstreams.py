#!/usr/bin/env python3

import json
import sys
import urllib.error
import urllib.request

API_URL = "http://127.0.0.1:8080/api/9/http/upstreams/"
TIMEOUT_SECONDS = 5

BAD_STATES = {"down", "unavail", "unhealthy"}
GOOD_STATES = {"up", "checking", "draining"}


def checkmk_escape(value):
    return str(value).replace("\n", "\\n").replace('"', "'")


def emit(state, service, metrics, message):
    print(f'{state} "{checkmk_escape(service)}" {metrics} {checkmk_escape(message)}')


def fetch_upstreams():
    req = urllib.request.Request(API_URL, headers={"Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=TIMEOUT_SECONDS) as response:
        return json.loads(response.read().decode("utf-8"))


def main():
    try:
        upstreams = fetch_upstreams()
    except urllib.error.URLError as err:
        emit(3, "NGINX Plus upstreams", "-", f"Unable to query {API_URL}: {err}")
        return
    except json.JSONDecodeError as err:
        emit(3, "NGINX Plus upstreams", "-", f"Invalid JSON from {API_URL}: {err}")
        return

    if not isinstance(upstreams, dict):
        emit(3, "NGINX Plus upstreams", "-", "Unexpected API response format")
        return

    total_upstreams = 0
    critical_upstreams = 0
    warning_upstreams = 0

    for upstream_name, upstream in sorted(upstreams.items()):
        peers = upstream.get("peers", [])
        primary_peers = [peer for peer in peers if not peer.get("backup", False)]

        total = len(primary_peers)
        up = sum(1 for peer in primary_peers if peer.get("state") in GOOD_STATES)
        bad = sum(1 for peer in primary_peers if peer.get("state") in BAD_STATES)
        other = total - up - bad

        bad_peer_details = [
            f'{peer.get("name", peer.get("server", "unknown"))}={peer.get("state", "unknown")}'
            for peer in primary_peers
            if peer.get("state") in BAD_STATES or peer.get("state") not in GOOD_STATES
        ]

        metrics = f"upstream_primary_peers={total}|upstream_peers_up={up}|upstream_peers_bad={bad}"

        service_name = f"NGINX Plus upstream {upstream_name}"

        if total == 0:
            warning_upstreams += 1
            emit(1, service_name, metrics, "No primary upstream peers found")
        elif up == 0:
            critical_upstreams += 1
            detail = ", ".join(bad_peer_details) or "no usable primary peers"
            emit(2, service_name, metrics, f"All primary upstream peers are unavailable: {detail}")
        elif bad > 0 or other > 0:
            warning_upstreams += 1
            detail = ", ".join(bad_peer_details)
            emit(1, service_name, metrics, f"{up}/{total} primary peers usable; problem peers: {detail}")
        else:
            emit(0, service_name, metrics, f"{up}/{total} primary peers usable")

        total_upstreams += 1

    summary_metrics = (
        f"upstreams={total_upstreams}|"
        f"critical_upstreams={critical_upstreams}|"
        f"warning_upstreams={warning_upstreams}"
    )

    if critical_upstreams:
        emit(
            2,
            "NGINX Plus upstream summary",
            summary_metrics,
            f"{critical_upstreams} upstreams have no usable primary peers; {warning_upstreams} degraded",
        )
    elif warning_upstreams:
        emit(
            1,
            "NGINX Plus upstream summary",
            summary_metrics,
            f"{warning_upstreams} upstreams degraded",
        )
    else:
        emit(
            0,
            "NGINX Plus upstream summary",
            summary_metrics,
            f"All {total_upstreams} upstreams have usable primary peers",
        )


if __name__ == "__main__":
    main()
