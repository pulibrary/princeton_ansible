# golang

This role installs a specific version of the Go toolchain from the official
`go.dev` tarballs into `/usr/local/go`, and ensures `go` is available on
`$PATH` via `/usr/local/bin/go`.

---

## What it does

On each run, the role:

1. Ensures the download directory (`{{ golang_download_dir }}`) exists.
2. Derives the correct architecture string (`amd64` / `arm64`) from
   `ansible_architecture` if you didn’t override `golang_arch`.
3. Downloads the versioned Go tarball
   (`go{{ golang_version }}.linux-{{ golang_arch }}.tar.gz`) from `go.dev`
   into `{{ golang_download_dir }}` if the file does **not** already exist.
4. If the tarball was downloaded/changed, it:
   - Extracts it into `/usr/local` (which creates/overwrites
     `{{ golang_install_dir }}`).
   - Ensures a symlink `/usr/local/bin/go` → `{{ golang_install_dir }}/bin/go`
     exists so `go` is on the PATH for non-interactive commands.

The role’s idempotence is driven by the **presence of the versioned tarball**:

- If `go{{ golang_version }}.linux-{{ golang_arch }}.tar.gz` already exists
  in `{{ golang_download_dir }}`, the install step is skipped.
- If you bump `golang_version`, the tarball name changes, so the role
  downloads the new tarball and re-installs Go.

> Note: This role assumes a typical Linux layout where `/usr/local` is
> writable by `root` and is intended to be run with `become: true`.

---

## Default variables

Defined in `roles/golang/defaults/main.yml`:

```yaml
# Go version to install (from go.dev)
golang_version: "1.25.5"

# Architecture string for Go tarball. Override if needed.
# Normally auto-detected from ansible_architecture, but you can force it.
golang_arch: "amd64"

# Where to cache downloaded tarballs
golang_download_dir: "/usr/local/src"

# Where Go will be installed
golang_install_dir: "/usr/local/go"
```

You can override these in group/host vars as needed, for example to pin a
different version:

```yaml
golang_version: "1.23.3"
```

### Example Usage

Simple Playbook:

```yaml
- name: Install modern Go from go.dev
  hosts: my_build_hosts
  become: true

  roles:
    - role: golang
```

After the role runs, you should see something like:

```bash
$ go version
go1.23.3 linux/amd64
```

and the binaries under `/usr/local/go/bin`


