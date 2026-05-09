## microk8s_cluster

Installs our  **MicroK8s** cluster, including multi-node join logic, high availability (HA) configuration, NFS server provisioning for storage, and automated UFW firewall management.

---

## Features

- **Automated Installation:** Installs MicroK8s and `kubectl` via snap.

- **Cluster Management:** Automatically handles node joining by fetching the join token from the primary node.

- **High Availability:** Supports enabling the `ha-cluster` addon.

- **NFS Storage:** Provisions an NFS server and enables the MicroK8s NFS CSI addon.

- **Security:** Manages UFW rules for internal cluster communication (Kubernetes API, dqlite, VXLAN, etc.).

- **Convenience:** Configures `.kube/config` for a designated admin user and handles group permissions.

---

## Role Variables

### MicroK8s Configuration

| **Variable**                    | **Default**                   | **Description**                                                        |
| ------------------------------- | ----------------------------- | ---------------------------------------------------------------------- |
| `microk8s_admin_user`           | `pulsys`                      | The system user who will manage the cluster.                           |
| `microk8s_snap_channel`         | `""`                          | Specific channel to track (e.g., `"1.32/stable"`). Empty uses default. |
| `microk8s_base_addons`          | `[dns, rbac, metrics-server]` | List of standard addons to enable.                                     |
| `microk8s_enable_ha_cluster`    | `true`                        | Whether to enable High Availability.                                   |
| `microk8s_install_kubectl_snap` | `true`                        | Installs the standalone `kubectl` snap for convenience.                |

### Inventory Group Mapping

The role uses specific groups to determine node tasks. You should define these in your inventory:

- `microk8s_cluster_group`: All nodes in the cluster.

- `microk8s_primary_group`: The single node used to generate join tokens.

- `microk8s_secondary_group`: Nodes that will join the primary.

- `microk8s_nfs_group`: The node(s) acting as an NFS server.

### NFS Configuration

| **Variable**                 | **Default**    | **Description**                           |
| ---------------------------- | -------------- | ----------------------------------------- |
| `nfs_export_path`            | `/var/nfs/k8s` | Directory to be exported via NFS.         |
| `nfs_export_allowed_clients` | `"*"`          | CIDR or wildcard for NFS client access.   |
| `microk8s_enable_nfs_addon`  | `true`         | Enables the MicroK8s community NFS addon. |

### Firewall (UFW)

| **Variable**                    | **Default**      | **Description**                                                |
| ------------------------------- | ---------------- | -------------------------------------------------------------- |
| `microk8s_manage_ufw`           | `true`           | Automatically open ports for K8s control plane and networking. |
| `microk8s_cluster_allowed_cidr` | `172.20.80.0/24` | The subnet allowed to communicate with the cluster.            |

---

## Dependencies

- `community.general` (for `snap` and `ufw` modules).

---

## Example Inventory


```toml
[k8s_microk8s:children]
k8s_microk8s_primary
k8s_microk8s_secondaries

[k8s_microk8s_primary]
node-01 ansible_host=172.20.80.10

[k8s_microk8s_secondaries]
node-02 ansible_host=172.20.80.11
node-03 ansible_host=172.20.80.12

[k8s_nfs]
node-01
```

---

## Example Playbook


```yaml
- hosts: all
  become: true
  roles:
    - role: microk8s_cluster
      vars:
        microk8s_admin_user: "admin"
        microk8s_snap_channel: "1.32/stable"
        microk8s_cluster_allowed_cidr: "10.0.0.0/16"
```

---

## Technical Flow

1. **NFS Setup:** If a host is in the NFS group, it configures `/etc/exports` and starts the service.

2. **Installation:** Installs MicroK8s on all nodes and adds the admin user to the `microk8s` group.

3. **Firewall:** Configures UFW to allow traffic between nodes for API and Pod networking.

4. **Primary Node Init:** Enables core addons (DNS, RBAC) and HA mode on the primary host.

5. **Join Sequence:**

   - Secondaries check if they are already members.

   - If not, the primary generates a token via `add-node`.

   - The secondary joins using the primary's IP/Token.

6. **Kubeconfig:** Fetches the internal config and places it in the admin user's `~/.kube/config`.

---

## License

MIT-0
