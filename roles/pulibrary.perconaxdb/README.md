Role Name
=========

This role installs a Percona XtraDB Cluster

Requirements
------------

None

Role Variables
--------------

Variables that can be changed are in `default/main.yml` and the ones that are
generally static are in `vars/main.yml`

Dependencies
------------

`pulibrary.common` and `pulibrary.samba` (for backup mounts)

Example Playbook
----------------

```
- hosts: percona_cluster_db
  gather_facts: true
  become: true
  roles:
    - role: pulibrary.perconaxdb
      xtradb_cluster_name: "pulibrary-cluster"
      xtradb_nodes_group: "percona_cluster_db"
      bind_interface: ens33

      xtradb_databases:
        - name: archivesspace
      xtradb_users:
        - name: archivesspace
          password: A_Vaulted_Password
          priv: 'archivesspace.*:GRANT,ALL'

```


Adding Users
------------

```
xtradb_users:
  - name: drupal
    password: A_Vaulted_password
    privs: "drupal.*:SUPER"

  - name: drupal_user
    password: A_Vaulted_password
    priv: 'drupaldb.*:ALL'
    host: '192.168.1.%'
```

License
-------

MIT

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
