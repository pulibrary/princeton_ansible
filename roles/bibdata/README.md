# bibdata

Ansible role for deploying and configuring the [Bibdata](https://github.com/pulibrary/bibdata) application at Princeton University Library. Bibdata is a Rails application that serves as a bridge between library data sources (Alma, SCSB, Figgy) and downstream consumers such as the catalog search index.

## Requirements

- Ansible ≥ 2.9
- Target host: Ubuntu 22.04 (Jammy)
- The `deploy_user` and `rust` roles must run before this role (see `molecule/default/converge.yml` for the full dependency order)
- The NFS server must be reachable when `running_on_server: true` and `nfs_server` is defined

## Role Variables

### Defaults (`defaults/main.yml`)

| Variable | Default | Description |
|---|---|---|
| `running_on_server` | `false` | Gates tasks that only apply to real deployments (NFS mounts, etc.). Set to `true` in host/group vars for non-local environments. |
| `bibdata_samba_source_host` | `bibdata-worker1.princeton.edu` | Hostname used as the Samba source for file shares. |
| `bibdata_data_dir` | `/data/bibdata_files` | Local path where the NFS share is mounted. |

### Vars (`vars/main.yml`)

| Variable | Value | Description |
|---|---|---|
| `capistrano_base_dir` | `/opt` | Base directory for Capistrano deployments. |
| `capistrano_directory` | `bibdata` | Application subdirectory under `capistrano_base_dir`. |

### Required variables (supplied by inventory/group vars)

| Variable | Description |
|---|---|
| `deploy_user` | OS user that owns the application files and runs Capistrano deploys. |
| `nfs_server` | Hostname or IP of the NFS server. Required when `running_on_server: true`. |

## Dependencies

This role has no `meta` dependencies, but the following roles should precede it in the play:

- `deploy_user` — creates the `deploy` OS user
- `ruby_app` — installs Ruby and Passenger
- `rust` — installs Rust toolchain system-wide (the `deploy` user is added to the `rustup` group by this role)
- `samba` — must run before `hr_share`

## What This Role Does

1. **Installs system packages**: `nfs-common`, `cifs-utils`, `python3-psycopg2`, `clang`
2. **Manages NFS mount**: mounts `<nfs_server>:/var/nfs/bibdata` at `/data/bibdata_files` and creates the required subdirectories on the NFS server (`scsb_update_files`, `figgy_ark_cache`)
3. **Manages RubyGems**: updates RubyGems to 3.6.8 and installs Bundler 2.6.8 as the default, removing the previous default gemspec (2.6.3)
4. **Creates Capistrano shared directory structure** for `marc_to_solr/translation_maps/`
5. **Creates a stub file** at `/opt/figgy_mms_ids.yaml` for the deploy user
6. **Adds `deploy` user to the `rustup` group** and `www-data` to the `deploy` group

## Example Playbook

```yaml
- hosts: bibdata
  become: true
  vars:
    running_on_server: true
    nfs_server: "lib-fs-<environments>.princeton.edu"
    deploy_user: deploy
  roles:
    - role: deploy_user
    - role: ruby_app
    - role: rust
    - role: bibdata
```

## Templates

| Template | Destination | Purpose |
|---|---|---|
| `nginx_extra_config` | Included by the nginx/passenger role | Adds CORS headers for `*.../context.json` endpoints |

## Files

Encrypted Ansible Vault credential files for Samba shares are stored under `files/`. These are referenced by the `samba` and `hr_share` roles and should not be decrypted outside of the standard `ansible-vault` workflow.

## Testing

Molecule tests use the `docker` driver against the `ghcr.io/pulibrary/vm-builds/ubuntu-22.04` image.

```bash
# From the role directory
molecule test

# Converge only (faster feedback loop)
molecule converge

# Run verify step against an existing instance
molecule verify
```

The verify playbook checks:

- `cifs-utils` and `python3-psycopg2` are installed
- The data directory (`bibdata_data_dir`) exists and is a directory

## License

MIT

## Author

