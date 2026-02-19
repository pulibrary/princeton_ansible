# Plakar

This role installs [plakar](https://plakar.io), builds the S3 integration plugin, and configures a backup repository stored in **AWS S3**.

It is designed so that:

- Servers never use personal GitHub or personal plakar.io accounts. (which is what the project documentation focuses on)
- S3 credentials and repository passphrase live in **Ansible Vault**.
- Each project (NFS, app servers, etc.) can define its own:
  - S3 bucket
  - IAM user / access keys
  - store name (`plakar_store_name`)
  - snapshot root path (`plakar_snapshot_root`)

---

## AWS Setup (one-time per bucket / project)

These steps are written for a single project (e.g. NFS backups).  
Other projects can repeat the same pattern with a different bucket and IAM user.

### Step 1: Create the S3 bucket

1. Log in to the **AWS Management Console**.
2. Go to **S3** (search for “S3” in the top search bar).
3. Click **Create bucket**.
4. Set:
   - **Bucket name**: e.g. `pul-nfs-backup` (must be globally unique).
   - **AWS Region**: `us-east-1`
5. Under **Block Public Access**:
   - Ensure **“Block all public access”** is **checked** (enabled).
6. Click **Create bucket** at the bottom.

### Step 2: Create a dedicated IAM user

Never use the AWS root account or a human user for automated backups.

1. Go to **IAM**.
2. Click **Users** in the left sidebar.
3. Click **Create user**.
4. Set:
   - **User name**: `plakar-nfs-backup-agent` (or similar, for example `plakar-postgresql-backup-agent`).
5. Click **Next** to go to permissions.

### Step 3: Grant permissions

Add the user to the `plakar-backup` Group with the `S3Full` Permissions

### Step 4: Generate access keys

1. After creating the user, click on the user name (e.g. `plakar-backup-agent`).
2. Go to the **Security credentials** tab.
3. Scroll to **Access keys** and click **Create access key**.
4. Choose **Command Line Interface (CLI)** (or “Other”).
5. Confirm the warning (checkbox) and click **Next**.
6. Click **Create access key**.

You’ll now see:

- **Access key ID**
- **Secret access key**

### Step 5: Save the keys in Ansible Vault

1. Copy both the **Access key ID** and **Secret access key**.
2. In your Ansible repo, open the appropriate Vault file (e.g. `group_vars/nfsserver/vault.yml`) and add:

   ```yaml
   vault_plakar_aws_access_key: "AKIA...."
   vault_plakar_aws_secret_key: "super-secret-key-here"
   vault_plakar_repo_passphrase: "super-long-random-passphrase"
```

3. Save and re-encrypt the file if needed:

  ```bash
  ansible-vault edit group_vars/nfsserver/vault.yml
  ```

> You will not be able to see the Secret Access Key in AWS again after leaving that page.
Treat it like a password.

## Variables

The role ships with sensible defaults in roles/plakar/defaults/main.yml, but these are the key variables you typically override per project / environment:

```yaml
# Which Unix user runs plakar (and owns ~/.config/.plakar)
plakar_user: "pulsys"

# Name of the AWS-backed store as seen by plakar
plakar_store_name: "nfs_aws"

# AWS S3 configuration
plakar_repo_bucket: "pul-nfs-backup"  # your bucket
plakar_repo_region: "us-east-1"

# From Ansible Vault
plakar_repo_access_key: "{{ vault_plakar_aws_access_key }}"
plakar_repo_secret_key: "{{ vault_plakar_aws_secret_key }}"
plakar_repo_passphrase: "{{ vault_plakar_repo_passphrase }}"

# What to back up
plakar_snapshot_root: "/var/nfs"
plakar_snapshot_excludes:
  - "*.tmp"
  - "cache/"

# Control whether the role creates the repo + runs an initial backup
plakar_configure_backup: true
plakar_run_initial_backup: true
```

The role will:

  1. Install plakar from the upstream apt repository.

  2. Build and install the S3 plugin if it’s not already installed.

  3. Configure an AWS store:

    ```bash
    plakar store add nfs_aws \
    s3://s3.us-east-1.amazonaws.com/pul-nfs-backup-aws \
    access_key=... secret_access_key=...
    ```
  1. Initialize the repository in that store:

    ```bash
    plakar at @nfs_aws create
    ```

  1. Run the initial backup (if plakar_run_initial_backup: true):

    ```bash
    plakar at @nfs_aws backup /var/nfs
    ```

### Example: using this role for NFS backups

Example: using this role for NFS backups (`playbooks/nfsserver.yml`)

```yaml
- name: configure nfsserver connection
  hosts: lib_fs_{{ runtime_env | default('staging') }}
  remote_user: pulsys
  become: true

  vars_files:
    - ../group_vars/nfsserver/{{ runtime_env | default('staging') }}.yml
    - ../group_vars/nfsserver/common.yml
    - ../group_vars/nfsserver/vault.yml

  roles:
    - role: roles/plakar
    - role: roles/nfsserver
```

Group vars (`group_vars/nfsserver/staging.yml`):

```yaml
# plakar backups
plakar_store_name: "nfs_aws"
plakar_repo_passphrase: "{{ vault_plakar_repo_passphrase }}"
plakar_repo_bucket: "pul-nfs-backup-aws"
plakar_repo_access_key: "{{ vault_plakar_aws_access_key }}"
plakar_repo_secret_key: "{{ vault_plakar_aws_secret_key }}"
plakar_snapshot_root: "/var/nfs"
plakar_configure_backup: true
plakar_run_initial_backup: true
```

After running the playbook, you can verify from the host:

```bash
sudo -u pulsys plakar store show nfs_aws
sudo -u pulsys plakar at @nfs_aws ls
```

And from AWS:

```bash
aws s3 ls s3://pul-nfs-backup
```

You should see plakar’s packfiles stored in the bucket.

#### Reusing the role for other projects

For a different project (e.g. backups of /var/lib/postgresql):

  1. Create a new S3 bucket + IAM user as above (or reuse an existing one).

  2. Add new vaulted secrets for that project’s access key / secret.

  3. Create a new group_vars/postgresql/<env>.yml that sets:

    ```yaml
    plakar_store_name: "postgresql_aws"
    plakar_repo_bucket: "pul-postgresql-backup"
    plakar_repo_access_key: "{{ vault_plakar_postgresql_aws_access_key }}"
    plakar_repo_secret_key: "{{ vault_plakar_postgresql_aws_secret_key }}"
    plakar_repo_passphrase: "{{ vault_plakar_postgresql_repo_passphrase }}"
    plakar_snapshot_root: "/var/lib/postgresql"
    plakar_configure_backup: true
    plakar_run_initial_backup: true
    ```
  1. Include the `plakar` role in that project’s playbook.

## Restore / Disaster Recovery

This section covers how to restore data from plakar when the repository is stored in AWS S3 via the `@<store>` pattern used by this role (e.g. `@nfs_aws`).

There are two common scenarios:

1. **Restore on the same host** (repo + store already configured by Ansible).
2. **Restore on a new host** (fresh machine, but S3 bucket still exists).

In both cases you’ll use `plakar restore` against the AWS-backed store. The syntax is:

```bash
plakar at @<store> restore -to <destination> <snapshotID>[:path]
```

as documented in the plakar restore / quickstart guides.

> **Passphrase reminder:** The Kloset store is encrypted. When prompted, use the passphrase stored in Ansible Vault as `vault_plakar_repo_passphrase`

### Restoring on the same host

Assumptions:

- The host is already managed by Ansible with this role.

- The store name is `nfs_aws` (or whatever you set in `plakar_store_name`).

- The S3 bucket and repo already exist.

#### 1.1 List available snapshots

As the `plakar_user` (usually `pulsys`):

```bash
sudo -u pulsys plakar at @nfs_aws ls
```

You’ll see a list of snapshot IDs (e.g. `9abc3294...`).

If plakar asks for a **repository passphrase**, use the value from:

```yaml
vault_plakar_repo_passphrase: "..."
```

in your project's Vault file.

#### 1.2 Restore an entire snapshot to a temporary location

Pick a snapshot ID (e.g. `9abc3294`) and restore it under /mnt/restore:

```bash
sudo -u pulsys plakar at @nfs_aws restore -to /mnt/restore 9abc3294
```

This will recreate the snapshot’s directory tree under /mnt/restore.

#### 1.3 Restore only a specific path

You can restore just a subdirectory (e.g. `/var/nfs/pas`) from that snapshot:

```bash
sudo -u pulsys plakar at @nfs_aws restore -to /mnt/restore 9abc3294:/var/nfs/bibdata
```

This is useful if you only need to recover one exported share.

#### 1.4 Copy restored data back into place

Once you’ve inspected the restored files under `/mnt/restore`, you can copy them back into the live filesystem. For example:

```bash
# Example only – adjust paths/flags to your policy
sudo rsync -aHAX --delete /mnt/restore/var/nfs/ /var/nfs/
```

### 2. Restoring on a new host

Assumptions:

- The original host was lost, but the S3 bucket is intact.

- You still have the Ansible repo and Vault file with:

  - `vault_plakar_aws_access_key`

  - `vault_plakar_aws_secret_key`

  - `vault_plakar_repo_passphrase`

#### 2.1 Rebuild the host and run Ansible

Provision a new VM / server.

1. Attach storage and create the mount point (e.g. `/var/nfs`).

2. Run the same Ansible playbook you use normally, with the same inventory / vars:

```bash
ansible-playbook playbooks/nfsserver.yml
```

This will:

- Install plakar and the S3 plugin.

- Re-create the `nfs_aws` store pointing at your existing S3 bucket.

- Not overwrite data in `/var/nfs` unless you also run the backup step.

#### 2.2 Verify connectivity to the store

On the new host:

```bash
sudo -u pulsys plakar store show nfs_aws
sudo -u pulsys plakar at @nfs_aws ls
```

You should see the existing snapshots from S3.

#### 2.3 Restore data to the new host

Restore all data to a staging location first:

```bash
sudo -u pulsys plakar at @nfs_aws restore -to /mnt/restore 9abc3294
```

Inspect the restored tree, then copy it into place:

```bash
sudo rsync -aHAX --delete /mnt/restore/var/nfs/ /var/nfs/
```

When you’re satisfied:

### 3. Quick reference

List snapshots:

```bash
sudo -u pulsys plakar at @nfs_aws ls
```

Inspect a snapshot in the UI:

```bash
sudo -u pulsys plakar at @nfs_aws ui
```

The tunnel to the resulting localhost:<port>

Restore everything from a snapshot:

```bash
sudo -u pulsys plakar at @nfs_aws restore -to /mnt/restore SNAPSHOT_ID
```

Restore a single directory:

```bash
sudo -u pulsys plakar at @nfs_aws restore -to /mnt/restore SNAPSHOT_ID:/var/nfs/bibdata
```

Remember: when prompted for the passphrase, use vault_plakar_repo_passphrase from Ansible Vault.
