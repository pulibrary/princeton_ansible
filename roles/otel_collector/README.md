# OpenTelemetry Collector (Contrib)

This role installs the OpenTelemetry Collector Contrib binary (otelcol-contrib) to /opt/otelcol on Linux servers.

It is opinionated and does the following:

  * Installs a specific version, defined by otel_version.

  * Only install the `amd64` architecture.

  * Deploys a generic, empty `config.yaml` to get the service started

## Role Variables

The following variables are available in `defaults/main.yml` and can be overridden: 

`otel_version`: "enter new value from upstream"

`otel_download_url`: "unlikely to change"
