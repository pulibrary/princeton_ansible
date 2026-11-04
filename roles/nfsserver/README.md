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

This copies `/var/nfs` to `gs://<bucket>/nfs/<env>` with `gcloud storage rsync`
on a daily systemd timer (`backup_sync.yml`), and mounts the bucket
with gcsfuse for browsing and monitoring (`backup_gcs_mount.yml`). The mount
logic is taken from [`solr9cloud`](../solr9cloud/tasks/backup_gcs_mount.yml),
including its stale-mount recovery.

The copy deliberately does not go through the mount. The first version ran rsync
over gcsfuse, and on lib-fs-prod (~650,000 files, 388G) every run took close to a
week, because rsync checks each file with its own round trip to GCS. gcloud lists
the bucket in bulk and only uploads what changed.

#### Switching a bucket that gcsfuse filled

Objects written through gcsfuse store their mtime under gcsfuse's own key, which
gcloud ignores. gcloud then uses the object's creation time instead, so on a
normal run every file looks changed and the whole tree is uploaded again (and,
with soft delete on the bucket, the overwritten copies are billed for a week).

Run the first backup by hand with `--checksums-only` instead. It compares hashes,
and where they match it only writes gcloud's mtime onto the object:

```sh
systemd-run --unit=nfs-backup-sync-checksums -p Nice=10 -p IOSchedulingClass=idle \
  /usr/local/sbin/nfs-backup-sync --checksums-only
tail -f /var/log/nfs-backup-sync.log
```

If the timer fires meanwhile, the lock makes that run step aside. Every run after
this one skips unchanged files on mtime and size alone.

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
root, so each run also writes `.ownership_manifest`: one line per path under the
source, `mode owner group type path<TAB>symlink-target`. **A restore has to
replay it**, or the applications reading the shares will fail on permissions.
gcloud does not copy symlinks, so they are recreated from the manifest too.

### What is monitored

A Checkmk local check reports the age of the last completed run, read from the
`.last_backup` marker through the mount, because a bucket with nothing being
copied into it looks perfectly healthy. It warns after
`nfsserver_backup_max_age_hours` (26 by default, just over a daily timer) and goes
critical at twice that, immediately if the last run failed, or if the mount is
missing or stale.

The sync script writes the marker only after gcloud exits cleanly, so a failed
upload can never refresh it. That is asserted in the molecule scenario, against a
stub `gcloud`. Progress is logged to `/var/log/nfs-backup-sync.log` every
`nfsserver_backup_progress_interval` seconds.

### Restoring

```sh
# stop exports so nothing writes while files are going back
systemctl stop nfs-kernel-server

export CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE=/etc/nfs-backup-account-key.json
export CLOUDSDK_CONFIG=/var/lib/nfs-backup/gcloud
gcloud storage rsync --recursive gs://pul-nfs-backup/nfs/production /var/nfs
gcloud storage cp gs://pul-nfs-backup/nfs/production/.ownership_manifest /root/

# recreate symlinks, then replay ownership and permissions, which the bucket
# could not hold
while IFS=' ' read -r mode user group type rest; do
  path=${rest%%$'\t'*}
  target=${rest#*$'\t'}
  [ "$type" = l ] && ln -sfn "$target" "$path"
  chown -h "$user:$group" "$path"
  [ "$type" = l ] || chmod "$mode" "$path"
done </root/.ownership_manifest

systemctl start nfs-kernel-server
```

## License

MIT
