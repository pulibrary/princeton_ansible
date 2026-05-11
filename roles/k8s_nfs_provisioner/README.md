# k8s_nfs_provisioner

Deploys [nfs-subdir-external-provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner) Helm chart to a **microk8s** cluster.  
It automatically creates an NFS-backed `StorageClass` and handles the entire installation via `microk8s helm3`.

## Requirements

- **microk8s** with the `helm3` add‑on enabled:

  ```bash
  microk8s enable helm3
  ```

- `kubectl` access (provided by `microk8s kubectl`)

- Target host must have [microk8s](../microk8s_cluster/) installed.

## Role Variables

All variables can be overridden in `defaults/main.yml` or passed directly in a playbook.

| Variable                    | Default                                                              | Description                                                   |
| --------------------------- | -------------------------------------------------------------------- | ------------------------------------------------------------- |
| `k8s_nfs_namespace`         | `platform`                                                           | Kubernetes namespace where the provisioner will be installed. |
| `k8s_nfs_chart_repo_name`   | `nfs-subdir-external-provisioner`                                    | Name of the Helm repository.                                  |
| `k8s_nfs_chart_repo_url`    | `https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/` | Helm repository URL.                                          |
| `k8s_nfs_chart_ref`         | `nfs-subdir-external-provisioner/nfs-subdir-external-provisioner`    | Fully qualified chart reference (repo name / chart name).     |
| `k8s_nfs_release_name`      | `nfs-subdir-external-provisioner`                                    | Helm release name.                                            |
| `k8s_nfs_server`            | `k8s-fs-staging.lib.princeton.edu`                                   | NFS server hostname or IP.                                    |
| `k8s_nfs_path`              | `/var/nfs/k8s`                                                       | NFS exported path.                                            |
| `k8s_nfs_storage_class`     | `k8s-fs-nfs`                                                         | Name of the StorageClass to create.                           |
| `k8s_nfs_default_class`     | `false`                                                              | Set the StorageClass as the cluster default (`true`/`false`). |
| `k8s_nfs_archive_on_delete` | `true`                                                               | Whether to archive volumes on PVC deletion (`true`/`false`).  |

## Dependencies

None.

## Example Playbook

```yaml

- hosts: k8s_primary
  become: true
  roles:
  - role: k8s_nfs_provisioner
    vars:
    k8s_nfs_server: "k8s-nfs.lib.princeton.edu"
    k8s_nfs_path: "/export/k8s"
    k8s_nfs_storage_class: "nfs-storage"
    k8s_nfs_default_class: true
```

After running the playbook, you can inspect the created `StorageClass`:

```bash
microk8s kubectl get storageclass
microk8s kubectl -n platform get pods
```

## License
