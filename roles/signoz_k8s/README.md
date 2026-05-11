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
| `signoz_chart_version`   | `""` (empty)               | Specific chart version to install. If empty, the latest version is used.       |
| `signoz_storage_class`   | `nfs`                      | Storage class to use for persistent volumes (passed to `global.storageClass`). |
| `signoz_service_type`    | `NodePort`                 | Kubernetes service type for the SigNoz frontend.                               |
| `signoz_http_node_port`  | `32080`                    | NodePort number when `signoz_service_type` is `NodePort`.                      |

> **Note:** The `global.storageClass` value is set only in the Helm values template; the role does not create the storage class itself – it must exist in the cluster.

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
