# Traefik Wall

This contains infrastructure for observability of some of our applications hosted on Nomad. It's mostly here to provide logging and metrics for staging resources that we can't put on Datadog, but need observability for during development.

## [Prometheus](https://prometheus.io/)

Prometheus is metrics scraping agent. Ours is configured to gather metrics from `/metrics` for all Nomad nodes registered in Consul that have the "metrics" tag.

Connections between the services secured by an auth token or basic auth.

Prometheus -> Nomad Applications: Auth Key (vault_metrics_auth_token)
Prometheus -> Node Exporter: Basic Auth (vault_metrics_basic_password)

## [Loki](https://grafana.com/docs/loki/latest/)

Loki is a logging endpoint. Ours is configured to have logs shipped to it from Promtail, configured in [log-shipping.hcl](deploy/log-shipping.hcl).

## [Grafana](https://grafana.com/oss/)

Grafana is a dashboard building and visualization application. You can find ours, on VPN, at [https://grafana-nomad.princeton.edu](https://grafana-nomad.lib.princeton.edu).

Grafana Github logins are restricted to the pulibrary Systems Developers team.

## [Promtail](https://grafana.com/docs/loki/latest/send-data/promtail/)

We're using Promtail to ship logs from containers to Loki. Now that Podman has support for [Vector](https://vector.dev/docs/), we should probably move to that eventually.

## Deployment

From `nomad` directory: `BRANCH=main ./bin/deploy observability <prometheus/loki/grafana/log-shipping>`

You can track progress and status of nomad apps by looking at the Nomad UI, accessible from `./bin/login`
