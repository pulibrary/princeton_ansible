# dss_processing

Mounts the DSS S3 buckets with [s3fs](https://github.com/s3fs-fuse/s3fs-fuse)
on AlmaLinux/Rocky, matching the `/etc/fstab` entries on dss2:

| Bucket             | Mount point      |
|--------------------|------------------|
| `dss-server-data3` | `/data3_AWS_S3`  |
| `dss-server-kaiko` | `/data/Kaiko`    |

The role installs `s3fs-fuse` from EPEL and `fuse3`, writes `/etc/passwd-s3fs` from the
vault, adds the mounts to `/etc/fstab` and mounts them. It also turns on the
`httpd_use_fusefs` SELinux boolean so Apache (the `httpd` role) can serve
files from them.

Vault variables:

```yaml
vault_dss_processing_s3_access_key_id: "<AWS access key id>"
vault_dss_processing_s3_secret_access_key: "<AWS secret access key>"
```

Set `dss_processing_s3_read_only: true` to mount every bucket read-only.

`/data` and `/data2` are local LVM volumes on dss2 and are not managed here.
