Role Name
=========

This installs Drupal 7 and/or 8 (depending on which variables one selects)

Requirements
------------

Each Role that utilizes the drupal role will need to define a template for settings.php.j2 that will get copied up to the server.  I tried having a default, but the overrides did not take in the inheriting roles.  See libwww for an example of a Drupal 7 file.  See recap-www for an example of a Drupal 8 file.

Role Variables
--------------

If you would like the role to not install a git repo (if you are utilizing capistrano for code maintenace set `drupal_git_repo: ''` )

```bash
drupal_docroot: "/var/www/drupal"
drupal_major_version: "8"
drupal_7_branch: "7.x"
drupal_8_branch: "8.7.x"
drupal_version_branch: "{{ drupal_8_branch if drupal_major_version == 8 else drupal_7_branch }}"
drupal_git_repo: "{{ drupal_local_repo | default('https://github.com/drupal/drupal.git') }}"
drupal_site_name: "Test site"
drupal_account_name: "{{ vault_drupal_admin | default('drupal_account') }}"
drupal_account_pass: "{{ vault_drupal_admin_pass | default('change_this') }}"
drush_path: "~/.composer"
mysql_root_home: /root
mysql_root_username: "root"
mysql_root_password: "{{ vault_maria_mysql_root_password | default('change_this') }}"
systems_user: "{{ deploy_user }}"

drupal_db:
  user: drupal
  password: "{{ drupal_db_password | default('change_this') }}"
  name: drupal

mysql_users:
  - name: "{{ drupal_db.user | default('drupal_user') }}"
    host: "%"
    password: "{{ drupal_db.password }}"
    priv: "{{ drupal_db.name }}.*:ALL"

mysql_databases:
  - name: "{{ drupal_db.name }}"
    encoding: utf8mb4
    collation: utf8mb4_general_ci
```


Dependencies
------------

- pulibrary.deploy-user
- pulibrary.php
- pulibrary.drush

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables
passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: roles/pulibrary.drupal}

License
-------

MIT

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
