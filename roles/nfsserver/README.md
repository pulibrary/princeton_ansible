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
nfsserver_exports:
  - share: /mnt/export
    hosts:
      - name: "10.0.0.0/24"
        options:
          - ro
          - no_subtree_check
           - nohide
      - name: "172.16.0.0/24"
        options:
          - rw
          - sync
          - no_wdelay
  - share: /mnt/export2
    hosts:
      - name: "10.2.3.0/24"
        options:
          - ro
```

License
-------

MIT
