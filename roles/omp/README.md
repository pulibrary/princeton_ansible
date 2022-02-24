Role Name
=========

This role installs Open Monograph Press (OMP) on Ubuntu

Requirements
------------

None

Role Variables
--------------

```bash
omp_version: "3.3.0-7"
omp_file_uploads: "/var/local/files"
omp_home: "/var/www/ojs-{{ ojs_version }}"
```

Dependencies
------------


Example Playbook
----------------

```
    - hosts: openbooks
      remote_user: pulsys
      become: true
      vars_files:
        - ../site_vars.yml
        - group_vars/omp/main.yml
        - group_vars/omp/vault.yml

      roles:
        - role: roles/omp
```

License
-------

MIT

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
