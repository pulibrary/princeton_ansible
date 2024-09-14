Role Name
=========

This role builds [nginx](https://www.phusionpassenger.com/library/install/nginx/install/oss/tarball/)

Requirements
------------


Role Variables
--------------

```bash
passenger_s_nginx_version: "1.25.2" # version of nginx
passenger_s_real_ip_from_staging
```
Dependencies
------------

The `ruby_s` role

Example Playbook
----------------

```bash
-e "passenger_app_env=dev real_ip_from={{ real_ip_from_staging }}"
```

The dev load balancer will need this flag
```


License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a website (HTML is not allowed).
