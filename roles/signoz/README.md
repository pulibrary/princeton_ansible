## SigNoz

This Ansible role installs and configures SigNoz, an open-source observability platform. It is designed to operate in two distinct modes:

 1. Local Server Mode: Deploys a full, self-contained SigNoz instance using Docker and Docker Compose. This is ideal for setting up a central observability server.

 2. Client Collector Mode: Installs and configures only the OpenTelemetry Collector (otelcol-contrib) to act as a client, sending telemetry data from a host to a remote SigNoz server (or any OTLP-compatible backend).

The mode is determined by the `signoz_is_local` boolean variable.

### Requirements
This role requires the following Ansible collections to be installed on your control node:

  - `community.general`

  - `community.docker`


### Role Variables
Variables are defined in defaults/main.yml.

**Global Control Variable**

This variable is mandatory and dictates the role's entire behavior.


|**Variable**  | **Type** | **Default** | **Description **|
|--|--|-:|-:|
|  `signoz_is_local`| boolean | `undefined` |(Required) Set to true to perform a full local SigNoz installation. Set to false to configure the host as a client with the OpenTelemetry Collector.  |

**Local Server Mode Variables** (`signoz_is_local: true`)

These variables are used when deploying a full SigNoz instance.

| **Variable** |** Default **|  **Description** |
|--|--|--|
| `signoz_install_dir` | `/opt/signoz` | The directory where the SigNoz git repository will be cloned. |
| `signoz_user` | `signoz` | The system user that will own the installation files. |
| `signoz_group`  | `signoz` | The system group for the signoz_user. |
|`signoz_repo_url`  | `https://github.com/SigNoz/signoz.git` | The URL of the SigNoz Git repository. |
| `signoz_repo_version` | `main` | The git branch, tag, or commit to check out for the installation. |

**Client Collector Mode Variables** (`signoz_is_local: false`)

These variables control the setup of the standalone OpenTelemetry Collector.

**Collector Installation**

| **Variable**  | **Default** | **Description** |
|--|--|--|
|`signoz_otelcol_version`  |`"0.129.1"`  | The version of the otelcol-contrib to download and install. |
| `signoz_otelcol_download_url`  | (see defaults/main.yml) | The full URL to download the collector archive. It is constructed using the version and architecture. |
| `signoz_otelcol_install_dir`  | `/opt/otelcol` | Directory where the collector binary will be installed. |
| `signoz_otelcol_config_dir` | `/etc/otelcol` | Directory for the collector's config.yaml. |


**Collector Configuration** (`config.yaml`)

The collector's config.yaml is generated from a template. You must define the pipeline components by setting the following variables in your playbook or inventory.

| **Variable**  | **Description** |
|--|--|
| `otel_receivers` | A dictionary defining the receivers section of the collector config. |
| `otel_processors` | A dictionary defining the processors section. |
| `otel_exporters` | A dictionary defining the exporters section. |
| `otel_service_pipelines` | A dictionary defining the service.pipelines section. |
| `otel_service_extensions`  | A list defining the service.extensions section. |
| `signoz_otlp_endpoint` | The host:port of the remote OTLP gRPC receiver. |


As an alternative to complex (used in postgresql and cdc) defining the individual components, you can provide the entire configuration as a single, pre-formatted YAML string using the `signoz_otel_config` variable.

### Example Playbooks
1. Deploy a Local SigNoz Server
This playbook will install Docker and deploy the full SigNoz platform on the target host.

```yaml
- hosts: signoz
  become: true
  roles:
    - role: signoz
      vars:
        signoz_is_local: true
```

2. Configure a Client Node to Send Host Metrics
This playbook installs the OpenTelemetry Collector on a client and configures it to send host metrics (CPU, memory, disk, etc.) to a remote SigNoz instance.

```yaml
- hosts: web_servers
  become: true
  # These variables define the OpenTelemetry Collector pipeline
  vars:
    otel_receivers:
      hostmetrics:
        scrapers:
          cpu:
          disk:
          filesystem:
          load:
          memory:
          network:
          paging:
          processes:
      otlp:
        protocols:
          grpc:
          http:

    otel_processors:
      batch: {}
      memory_limiter:
        check_interval: 1s
        limit_percentage: 75
        spike_limit_percentage: 15

    otel_exporters:
      otlp:
        endpoint: "{{ signoz_otlp_endpoint }}"
        tls:
          insecure: true

    otel_service_extensions: []

    otel_service_pipelines:
      metrics:
        receivers: [hostmetrics]
        processors: [memory_limiter, batch]
        exporters: [otlp]
      logs:
        receivers: [otlp]
        processors: [memory_limiter, batch]
        exporters: [otlp]
      traces:
        receivers: [otlp]
        processors: [memory_limiter, batch]
        exporters: [otlp]

  roles:
    - role: signoz
      vars:
        # Set to client mode
        signoz_is_local: false
        # Specify the remote SigNoz server endpoint
        signoz_otlp_endpoint: "sandbox-signoz1.lib.princeton.edu:4317"
```
