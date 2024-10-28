Role Name
=========

Installs and configures NFS

Requirements
------------

NA

Role Variables
--------------

In your group vars create your share definition using the example in
[defaults/main.yml](defaults/main.yml)

```yaml
shares:
  - mount: "/var/nfs/bibdata"
    name: "bibdata"
    hosts:
      - "{{ servers.bibdata.staging1 }}"
...
nfsserver_exports:
  - share: "{{ bibdata_fileshare_mount }}"
    hosts:
      - name: "{{ servers.bibdata.staging1 }}"
        options: "{{ default_nfs_option }}"
```

If you have different needs than the default_nfs_option. Add this to your `group_vars/project/environment.yml`

```yaml
default_nfs_option:
  - ro
```

License
-------

MIT
