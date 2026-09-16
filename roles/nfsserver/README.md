# Role Name

Installs and configures NFS

## Requirements

NA

## Role Variables

In your group vars create your share definition using the example in
[defaults/main.yml](defaults/main.yml)

```yaml
# mounts
bibdata_fileshare_mount: "/var/nfs/bibdata"
# servers
bibdata_staging1: "18.19.20.21"
...
# exports
nfsserver_exports:
  - share: "{{ bibdata_fileshare_mount }}"
    hosts:
      - name: "{{ bibdata_staging1 }}"
        options: "{{ default_nfs_option }}"
```

If you have different needs than the default_nfs_option. Add this to your `group_vars/project/environment.yml`

```yaml
default_nfs_option:
  - ro
  - nohide
```

## Backing up the exported trees to GCS

Off by default. Turn it on per environment:

```yaml
nfsserver_backup_enabled: true
nfsserver_backup_bucket: pul-nfs-backup
```

This mounts a GCS bucket with gcsfuse and copies `/var/nfs` into it on a systemd
timer. The mount logic is taken from
[`solr9cloud`](../solr9cloud/tasks/backup_gcs_mount.yml), including its
stale-mount recovery, because a dead FUSE endpoint fails the same way wherever it
happens: the mount stays listed in the kernel mount table while every write to it
fails.

The Solr role stops at the mount because Solr writes its own backups into it
through its backup API. Nothing does that for an NFS export, so a mounted bucket
on its own would back up nothing at all. `backup_sync.yml` is the part that
copies.

### What it needs first

- A bucket, with **object versioning and a lifecycle policy**. See the note on
  deletions below.
- A service account key with write access to that bucket, placed at
  `files/nfs-backup-<env>-account-key.json` in the playbook. Not in this repo.

### Deletions are not propagated

`nfsserver_backup_delete` is `false`. With it on, anything deleted or encrypted
on a share is deleted from the backup on the next run, which is exactly when the
backup is wanted. Leave it off, or enable it only once bucket versioning is
keeping previous versions.

The tradeoff is that removed files stay in the bucket, so it grows. A lifecycle
policy on the bucket is the right place to bound that, not `--delete`.

### Ownership is stored separately

Object storage cannot hold POSIX ownership, and these trees are owned by several
accounts (`deploy`, `conan`, others). Every object in the bucket reads back as
root, so each run also writes `.ownership_manifest`: mode, owner, group and path
for everything under the source. **A restore has to replay it**, or the
applications reading the shares will fail on permissions.

### What is monitored

A Checkmk local check reports the age of the last completed run, not merely that
the mount exists, because a mounted bucket with nothing being copied into it looks
perfectly healthy. It warns after `nfsserver_backup_max_age_hours` (26 by default,
just over a daily timer) and goes critical at twice that, or immediately if the
mount is missing or stale.

The sync script also refuses to run unless its destination is genuinely a mount
point, so a backup attempted while the mount was down cannot quietly write to the
root filesystem and fill the disk. That refusal is asserted in the molecule
scenario.

### Restoring

```sh
# stop exports so nothing writes while files are going back
systemctl stop nfs-kernel-server

rsync -a /var/backups/nfs_cloud_backup/nfs/production/ /var/nfs/

# replay ownership and permissions, which the bucket could not hold
awk '{ mode=$1; user=$2; group=$3; $1=$2=$3=""; sub(/^ +/, ""); \
  printf "chown %s:%s \"%s\"; chmod %s \"%s\"\n", user, group, $0, mode, $0 }' \
  /var/backups/nfs_cloud_backup/nfs/production/.ownership_manifest | bash

systemctl start nfs-kernel-server
```

## License

MIT
