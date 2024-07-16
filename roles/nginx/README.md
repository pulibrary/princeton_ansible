Nginx
=========

Installs upstream version of nginx

Requirements
------------

Ubuntu Linux

Role Variables
--------------

* `nginx_config_file` (default: `/etc/nginx/conf.d/default.conf`)
   * The directory where NGINX configuration files are stored.

Dependencies
------------


Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: username.rolename, x: 42 }

License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a website (HTML is not allowed).
