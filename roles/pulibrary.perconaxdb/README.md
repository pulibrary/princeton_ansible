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

```

Adding Databases and Users
------------

This should be done via the `pulibrary.mariadb` role

Migrating your role's database from the MariaDB cluster to Percona
------------

1. Change molecule in your role to run a percona server

   1. Modify the molecule playbook to include a pre_task in `<your role>/molecule/default/playbook.yml`

      ```
        pre_tasks:
          - name: install iproute
            apt:
              name: iproute2
              state: present
          - name: rerun setup
            setup:
              gather_subset:
                - network
      ```
    
    1. Modify the molecule playbook to include a new vars for percona in `<your role>/molecule/default/playbook.yml`
       ```
         - xtradb_nodes_group: "all"
         - xtradb_leader_node: "instance"
       ```

    1. Modify the molecule playbook to use the perconaxdb role in `<your role>/molecule/default/playbook.yml`
       ```
         - role: pulibrary.perconaxdb        
       ```

    Full example playbook below
    ```
    ---
    - name: Converge
      hosts: all
      pre_tasks:
      - name: install iproute
        apt:
          name: iproute2
          state: present
      - name: rerun setup
        setup:
          gather_subset:
            - network
      vars:
        - run_not_in_container: false
        - xtradb_nodes_group: "all"
        - xtradb_leader_node: "instance"
      roles:
        - role: pulibrary.perconaxdb
        - role: pulibrary.<your role>
    ```

  1. Modify your group_vars for your playbook database_host & database_password

      ```
      db_host: 'maria-< staging | prod >.princeton.edu'
      db_password: "{{ vault_xtradb_root_password }}"
      ```

License
-------

MIT

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
