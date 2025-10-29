# OpenTelemetry Collector (Contrib)

This role installs **otelcol-contrib** and renders a fully data-driven `config.yaml`.  
You define receivers/processors/exporters/pipelines in `group_vars` or `host_vars`, and the role does the rest.

## What it does

- Downloads and unpacks a specific `otelcol-contrib` version to `/opt/otelcol`.
- Renders `config.yaml` from your vars (no hardcoding).
- Optionally:
  - Validates the config with `--dry-run`.

## Requirements

- Linux host (tested with Ubuntu/Rocky).
- `otelcol-contrib` tarball for `amd64` (default URL points to upstream releases).

## Role Variables (defaults)

See `defaults/main.yml` for the full list. Key ones:

- `otel_version`: Collector version (default: `0.138.0`)
- `otel_install_dir`, `otel_binary_path`, `otel_config_path`: Install locations
- `otel_download_url`: Download URL (amd64)
- `otel_validate_config`: If `true`, run a validation command after templating (default: `false`)
- `otel_receivers`, `otel_processors`, `otel_exporters`, `otel_service_pipelines`, `otel_extensions`: Core config dicts/lists (default: empty)
- `otel_default_resource_attributes`: Map of resource attributes to **merge** into a `processors.resource` section (as *upsert* actions)

## How to use

1. Set variables in `group_vars/<project>/<env>.yml` (or host_vars). Example:

   ```yaml
   otel_default_resource_attributes:
     host.name: lib-postgres-staging1
     service.name: postgresql-server
     service.version: staging
     environment: staging

   otel_receivers:
     filelog/postgresql:
       include: ["/var/lib/postgresql/15/main/pg_log/pg.json*"]
       start_at: end
       operators:
         - type: add
           field: attributes.log_source
           value: postgresql-server
     postgresql:
       endpoint: "localhost:5432"
       transport: tcp
       username: monitoring
       password: "{{ vault_postgres_monitoring_password }}"
       collection_interval: 300s
       databases: ["postgres"]
     hostmetrics:
       collection_interval: 30s
       scrapers: { cpu: {}, disk: {}, filesystem: {}, load: {}, memory: {}, network: {} }

   otel_processors:
     batch: { send_batch_max_size: 1024, send_batch_size: 512, timeout: 30s }

   otel_exporters:
     otlp:
       endpoint: "http://sandbox-signoz1.lib.princeton.edu:4317"
       tls: { insecure: true }
     debug: { verbosity: basic }

   otel_service_pipelines:
     logs:
       receivers: ["filelog/postgresql"]
       processors: ["resource", "batch"]
       exporters: ["otlp", "debug"]
     metrics:
       receivers: ["hostmetrics", "postgresql"]
       processors: ["resource", "batch"]
       exporters: ["otlp", "debug"]
```
