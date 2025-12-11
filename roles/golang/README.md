# golang

This role installs a specific version of the Go toolchain from the official
`go.dev` tarballs into `/usr/local/go`, and ensures `go` is available on
`$PATH` via `/usr/local/bin/go`.

---

## What it does

On each run, the role:

1. Figures out the correct architecture string (`amd64` / `arm64`) if you
   didn’t override it.
2. Checks if `{{ golang_install_dir }}/bin/go` exists and what version it is.
3. If the version doesn’t match `golang_version`:
   - Downloads `https://go.dev/dl/go{{ golang_version }}.linux-{{ golang_arch }}.tar.gz`
     into `{{ golang_download_dir }}`.
   - Removes any existing installation at `{{ golang_install_dir }}`.
   - Extracts the new Go tree into `/usr/local`.
4. Ensures a symlink `/usr/local/bin/go` → `{{ golang_install_dir }}/bin/go`
   exists so `go` is on the PATH for non-interactive commands.

The role is idempotent: if the requested version is already installed, no
downloads or changes occur.

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
You can override these in group/host vars as needed, for example to pin a
different version:

```

```yaml
golang_version: "1.23.3"
```

Example usage
Simple playbook:

```yaml
- name: Install modern Go from go.dev
  hosts: my_build_hosts
  become: true

  roles:
    - role: golang
```

With overrides:

```yaml
- name: Install Go 1.23.3 on AMD64
  hosts: my_build_hosts
  become: true

  vars:
    golang_version: "1.23.3"
    golang_download_dir: "/var/cache/go-downloads"

  roles:
    - role: golang
```

After the role runs, you should see something like:

```bash
$ go version
go1.23.3 linux/amd64
```

and the binaries under `/usr/local/go/bin.`
