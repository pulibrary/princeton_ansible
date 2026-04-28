# pulmirror

An Ansible role to provision a FreeBSD-based mirror host with:

- nginx (HTTPS-enabled)
- ACME certificates via lego (DNS-01 using DNSimple)
- Automated certificate renewal
- Node.js distribution mirror (rsync-based, from dotsrc tier-1)
- Apache Solr distribution mirror (rsync-based, from rsync.us.apache.org)
- Log rotation and scheduled sync

---

## Requirements

- FreeBSD host (tested on 15.0-RELEASE)
- DNS hosted in DNSimple (or delegated for DNS-01)
- Ansible with `community.general` collection
- Outbound TCP/873 (rsync) allowed in firewall/VPC egress
- A dedicated ZFS pool for mirror content (see "Storage layout" below)

```bash
ansible-galaxy collection install community.general
```

---

## What this role does

### TLS (lego + DNSimple)

- Uses lego with DNS-01 challenge
- Stores certs under `/usr/local/etc/lego/certificates/`
- Automatically renews via cron
- Reloads nginx on renewal

### nginx

- Installs [nginx](../nginx)
- Creates `/usr/local/etc/nginx/conf.d/`
- Ensures `nginx.conf` includes `conf.d/*.conf`
- Configures HTTP → HTTPS redirect
- Serves either static content or reverse proxy

### Node.js mirror

Mirrors Node.js distribution files using rsync from a tier-1 upstream:

```text
rsync://mirrors.dotsrc.org/nodejs/
```

Dotsrc (Aalborg University) is a public mirror that syncs from nodejs.org
approximately every 6 hours.

- Stores content under `/usr/local/www/nginx-dist/mirror/nodejs`
- Efficient delta transfers (only changed files)
- Preserves hard links (`--hard-links`)
- Deletes removed upstream files (`--delete`)
- Uses lockfile + pgrep pre-flight to prevent concurrent runs
- Handles partial transfers gracefully (rsync rc=23,24 → non-fatal)
- Atomic publishing via `--delay-updates --partial` (steady-state mode)
- Logs to `/var/log/nodejs-mirror.log`, rotated by newsyslog

### Apache Solr mirror

Mirrors current Solr releases using rsync from Apache's official endpoint:

```text
rsync://rsync.us.apache.org/apache-dist/solr/         (9.x and current)
rsync://rsync.us.apache.org/apache-dist/lucene/solr/  (8.x and earlier)
```

Follows ASF mirror etiquette: `--safe-links`, off-the-hour scheduling,
polite bandwidth limit, max 4-6 syncs per day.

- Stores content under `/usr/local/www/nginx-dist/mirror/solr/{current,legacy}`
> Note: archived versions (pre-7.x) were manually added and are
  NOT included in the rsync script — that tree is HTTP-only and would require a separate
  wget-based companion script

---

## Storage layout

This role assumes mirror content lives on a dedicated ZFS pool. The
recommended layout uses one dataset per mirror so you can quota, snapshot,
and replicate them independently.

### Initial pool setup (manual, one-time)

```bash
# Created the pool on a dedicated disk (e.g. da1 in GCP/AWS)
doas zpool create -o autoexpand=on -O compression=lz4 -O atime=off pubmirror /dev/da1

# Create per-mirror datasets
doas zfs create -o mountpoint=/usr/local/www/nginx-dist/mirror pubmirror/nginx
doas zfs create -o mountpoint=/usr/local/www/nginx-dist/mirror/solr pubmirror/solr
```

### Pool naming caveats

ZFS rejects pool names beginning with reserved keywords:
`mirror`, `raidz`, `draid`, `spare`, `log`, `cache`. Pick something else
(`pubmirror`, `pkgmirror`, `tank`, etc.).

### Quotas

Quotas are useful as operational hygiene but cause hard failures when
hit. Recommendations:

- **nginx (nodejs)**: leave unquota'd. nodejs.org/dist is currently ~1+ TB
  and grows continuously; a quota that's slightly too tight will cause
  rsync to fail mid-transfer and require manual intervention.
- **solr**: 100 GB is plenty (current usage is single-digit GB).
- **Future mirrors**: cap modestly (e.g., Apache HTTPD ~5 GB, Maven Central
  fragments are larger).

```bash
doas zfs set quota=100G pubmirror/solr
```

### Disk size planning

Approximate storage requirements based on observed usage:

| Mirror | Initial seed | Steady-state growth |
|--------|--------------|---------------------|
| nodejs | ~1.0–1.1 TB  | ~5–10 GB/month      |
| solr   | ~1.6 GB      | <1 GB/month         |

A 2 TB GCP `pd-balanced` disk (~1.86 TiB usable) is sufficient for both
mirrors plus growth and additional small mirrors (Apache HTTPD, Tomcat,
Maven artifacts, etc.).

---

## Initial seeding

The first sync of nodejs is multi-hour due to file count, not byte count.
There are tens of thousands of version directories under `nightly/`, `rc/`,
`release/`, and `test/`. The role supports a **one-time seed mode** that
drops `--delay-updates` and `--partial` from the rsync invocation.

**Use seed mode when:**

- The mirror tree is empty or you've just attached a fresh disk
- nginx is not yet serving content (so partial files are not a concern)

**Do not use seed mode when:**

- The mirror is already serving traffic — partial files would be visible
  to clients mid-transfer

### Seed mode invocation

```bash
# nodejs
ssh pulmirror
tmux new -s mirror
doas env NODEJS_MIRROR_INITIAL_SEED=1 /usr/local/sbin/sync-nodejs-mirror
# Detach: Ctrl-b d

# solr (much smaller, usually unnecessary but supported)
doas env SOLR_MIRROR_INITIAL_SEED=1 /usr/local/sbin/sync-solr-mirror
```

The script logs a line confirming seed mode at the start of the run.

### Recommended workflow

1. Stop cron so it doesn't race the seed:
   `doas service cron stop`
2. Run the seed in tmux as shown above.
3. When complete (look for the `total size is ...` stats block in the log),
   re-enable cron:
   `doas service cron start`
4. The next cron tick will run in steady-state mode (with atomic publishing).

---

## Migrating a populated mirror to production

Once seeded on a test host, the entire mirror can be moved to production
by detaching the GCP disk and reattaching it to the prod VM. The pool is
self-describing and ZFS handles the import cleanly.

### On the test server

```bash
# Stop services touching the mount
doas service cron stop
doas pkill -f sync-nodejs-mirror
doas pkill -f sync-solr-mirror

# Export the pool (flushes I/O, unmounts datasets cleanly)
doas zpool export pubmirror
```

### On GCP

```bash
gcloud compute instances detach-disk pultestmirror \
  --zone=us-central1-f --disk=pultestmirror-mirror

gcloud compute instances attach-disk pulmirror \
  --zone=us-central1-f --disk=pultestmirror-mirror --device-name=mirror
```

Both VMs must be in the same zone.

### On the production server

```bash
# Confirm the new disk
geom disk list

# Import the pool — datasets mount at their recorded mountpoints
doas zpool import pubmirror

# Verify
zpool status pubmirror
zfs list -r pubmirror
mount | grep mirror
```

After import, the role's cron jobs will continue syncing on the prod VM.
No re-seed is required.

---

## Variables

### Core

```yaml
pulmirror_domain: "example.org"
pulmirror_domains:
  - "example.org"

pulmirror_email: "admin@example.org"
```

### ACME / DNSimple

```yaml
pulmirror_dns_provider: "dnsimple"
```

### Paths

```yaml
pulmirror_path: "/usr/local/etc/lego"
pulmirror_ssl_certificate: "/usr/local/etc/lego/certificates/<domain>.crt"
pulmirror_ssl_certificate_key: "/usr/local/etc/lego/certificates/<domain>.key"
pulmirror_nginx_conf: "/usr/local/etc/nginx/conf.d/<domain>.conf"
```

### Node.js mirror

```yaml
nodejs_mirror_root: /usr/local/www/nginx-dist/mirror/nodejs
nodejs_mirror_source: "rsync://mirrors.dotsrc.org/nodejs/"
nodejs_mirror_owner: www
nodejs_mirror_group: www
nodejs_mirror_bwlimit: 10000          # KB/s
nodejs_mirror_cron_hour: "*/6"
nodejs_mirror_cron_minute: "17"
```

### Solr mirror

```yaml
solr_mirror_root: /usr/local/www/nginx-dist/mirror/solr
solr_mirror_owner: www
solr_mirror_group: www
solr_mirror_source_host: "rsync.us.apache.org"
solr_mirror_paths:
  - { remote: "solr/", local: "current" }
  - { remote: "lucene/solr/", local: "legacy" }
solr_mirror_bwlimit: 5000             # KB/s
solr_mirror_cron_hour: "*/6"
solr_mirror_cron_minute: "23"
```

---

## Example

```yaml
- hosts: pulmirror_staging
  become: true
  roles:
    - role: pulmirror
      vars:
        pulmirror_domain: "pultestmirror.pulcloud.io"
        pulmirror_domains:
          - "pultestmirror.pulcloud.io"
        pulmirror_email: "lsupport@princeton.edu"
        pulmirror_use_staging: true
        pulmirror_dnsimple_oauth_token: "{{ vault_dnsimple_oauth_token }}"
```

---

## Troubleshooting

### Certificate issuance fails

Run manually on host:

Common issues:

- DNSimple token lacks access to the zone
- Wrong domain (zone mismatch)
- Missing DNS delegation for `_acme-challenge`

### nodejs-mirror or solr-mirror cron runs silently exit

Each script uses `lockf -t 0` plus a `pgrep` check to prevent overlap.
If a previous run is still active (or stuck), subsequent runs exit with
code 0 and a log line:

```text
another rsync is already targeting /usr/local/www/nginx-dist/mirror/nodejs, exiting
```

To investigate:

```bash
doas ps auxww | grep -E '(rsync|sync-nodejs|sync-solr|lockf)' | grep -v grep
doas fstat /var/run/nodejs-mirror.lock
```

If a stuck process needs killing, use `pkill -f sync-nodejs-mirror` plus
`pkill -f 'rsync.*nodejs'`. Note that rsync forks into a parent/child
pair during transfer — both belong to one logical invocation. Verify
parent/child relationships with `ps -o pid,ppid,command` before assuming
duplicates.

### rsync hits "Disc quota exceeded"

ZFS quota is too tight. Check with:

```bash
zfs list pubmirror/nginx
```

If `AVAIL` is `0B`, raise or remove the quota:

```bash
doas zfs set quota=none pubmirror/nginx
```

Then re-run the script. rsync's `--partial` flag means most of the
already-downloaded content is reused.

### Mirror tree owned by 1004:1004 instead of www:www

The script's final `chown -R "$OWNER" "$MIRROR_ROOT"` runs only on
successful rsync completion. If a previous run died (quota error, kill,
network failure), ownership remains as upstream provided. Fix manually:

```bash
doas chown -R www:www /usr/local/www/nginx-dist/mirror/nodejs/
```

### Apache rsync rejects connection or returns errors

Apache mirrors enforce mirror etiquette. If your sync schedule is too
aggressive (more than 6 times per day, or runs at minute 0), the upstream
may rate-limit or refuse you. The defaults in this role (every 6 hours
at minute 23) are within policy.

---

## DNS-01 caveat

ACME validation happens at:

```text
_acme-challenge.<domain>
```

If your public name is `pultestmirror.princeton.edu` but DNS is hosted in
`pulcloud.io`, you must either:

- issue the cert for the `pulcloud.io` name, **or**
- delegate `_acme-challenge.pultestmirror.princeton.edu` via CNAME to a
  record in `pulcloud.io`

---

## Notes

- Role is FreeBSD-specific
- Uses `pkg` (not `apt`/`yum`)
- nginx runs as `www`
- Logs rotated by `newsyslog` via drop-ins in `/usr/local/etc/newsyslog.conf.d/`
- The `pulmirror` pool name is conventional for this role; the script
  paths and ZFS dataset names assume `pubmirror/nginx` and `pubmirror/solr`.
  If you use different names, override `nodejs_mirror_root` and
  `solr_mirror_root` and create matching datasets.
