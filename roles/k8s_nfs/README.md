## k8s_nfs

Install and configure an **NFS Server** specifically tailored for **MicroK8s** storage. This role sets up the necessary exports, permissions, and firewall rules to allow a Kubernetes cluster to use the host as a persistent storage backend.

---

## Features

- Installs `nfs-kernel-server` and `nfs-common`.

- Creates a dedicated NFS export directory (default: `/var/nfs/k8s`).

- Configures `/etc/exports` with optimized flags for Kubernetes (`no_root_squash`).

---

## Role Variables

The following variables are defined in `defaults/main.yml`. You can override these in your playbook or host variables.

| Variable                     | Default Value                                  | Description                            |
| ---------------------------- | ---------------------------------------------- | -------------------------------------- |
| `nfs_export_path`            | `/var/nfs/k8s`                                 | The directory shared over NFS.         |
| `nfs_export_allowed_clients` | `172.20.80.0/24`                               | The CIDR block of your MicroK8s nodes. |
| `nfs_export_options`         | `[rw, sync, no_subtree_check, no_root_squash]` | Export configuration flags.            |
| `nfs_export_mode`            | `"0755"`                                       | Permissions for the export directory.  |

---

## Requirements

- **OS:** Ubuntu/Debian (uses `apt` and `ufw`).

- **Privileges:** Must be run with `become: true`.

---

## Dependencies

- `community.general` collection (for `ufw` module support).

---

## Example Playbook

```yaml
- hosts: storage_servers
  become: true
  roles:
    - role: k8s_nfs
      vars:
        nfs_export_path: "/data/k8s_storage"
        nfs_export_allowed_clients: "10.0.0.0/24"
```

---

## File Structure Explained

- **`tasks/main.yml`**: Handles package installation, directory creation, and service management.

- **`templates/exports.j2`**: A dynamic template for `/etc/exports` using the variables defined in defaults.

- **`handlers/main.yml`**: Ensures that the NFS server restarts or reloads exports only when configuration changes occur.

---

