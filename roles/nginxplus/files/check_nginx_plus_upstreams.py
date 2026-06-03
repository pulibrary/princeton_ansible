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


def tally(peers):
    """Return (total, up, bad, other) counts for a group of peers."""
    total = len(peers)
    up = sum(1 for peer in peers if peer.get("state") in GOOD_STATES)
    bad = sum(1 for peer in peers if peer.get("state") in BAD_STATES)
    other = total - up - bad
    return total, up, bad, other


def problem_details(peers):
    """Comma-joined 'name=state' for peers that are bad or in an unexpected state."""
    return ", ".join(
        f'{peer.get("name", peer.get("server", "unknown"))}={peer.get("state", "unknown")}'
        for peer in peers
        if peer.get("state") in BAD_STATES or peer.get("state") not in GOOD_STATES
    )


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

    for upstream_name, upstream in sorted(upstreams.items()):
        peers = upstream.get("peers", [])
        primary_peers = [peer for peer in peers if not peer.get("backup", False)]
        backup_peers = [peer for peer in peers if peer.get("backup", False)]

        p_total, p_up, p_bad, p_other = tally(primary_peers)
        b_total, b_up, b_bad, b_other = tally(backup_peers)

        bad_primary = problem_details(primary_peers)
        bad_backup = problem_details(backup_peers)

        metrics = (
            f"upstream_primary_peers={p_total}|"
            f"upstream_peers_up={p_up}|"
            f"upstream_peers_bad={p_bad}|"
            f"upstream_backup_peers={b_total}|"
            f"upstream_backup_peers_up={b_up}|"
            f"upstream_backup_peers_bad={b_bad}"
        )

        service_name = f"NGINX Plus upstream {upstream_name}"

        if p_total == 0 and b_total == 0:
            emit(1, service_name, metrics, "No upstream peers found")

        elif p_up > 0:
            # At least one primary is usable.
            if p_bad > 0 or p_other > 0:
                emit(
                    1,
                    service_name,
                    metrics,
                    f"{p_up}/{p_total} primary peers usable; problem peers: {bad_primary}",
                )
            else:
                emit(0, service_name, metrics, f"{p_up}/{p_total} primary peers usable")

        elif b_up > 0:
            # No usable primaries, but backups are up and serving traffic.
            # Degraded, not down: warn instead of crit.
            primary_detail = bad_primary or "no usable primary peers"
            emit(
                1,
                service_name,
                metrics,
                f"All primaries unavailable; serving from {b_up}/{b_total} "
                f"backup peers (primaries: {primary_detail})",
            )

        else:
            # No usable primaries and no usable backups: genuinely down.
            primary_detail = bad_primary or "no primary peers"
            if b_total == 0:
                detail = f"primaries: {primary_detail}; no backup peers defined"
            else:
                detail = f"primaries: {primary_detail}; backups: {bad_backup or 'none usable'}"
            emit(2, service_name, metrics, f"No usable peers ({detail})")


if __name__ == "__main__":
    main()
