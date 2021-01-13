Role Name
=========

Creates a Drupal 7 Friends of PUL machine that is ready to have the code deployed by capistrano.

Requirements
------------

The drupal role is utilized to perform all of the tasks.

Role Variables
--------------

drupal_db_user - Mysql Database user for drupal, Default `fpul`
drupal_db_password - Mysql Database password for drupal, Default `changeme`
drupal_db_name - Mysql Database name for drupal, Default `fpul`
drupal_db_host - Host that serves the database, Default `localhost`
drupal_db_port - Port on the host that serves the database, Default `3306`

Dependencies
------------

None

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { friends_of_pul }

License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a website (HTML is not allowed).
