Nginx
=========

Installs upstream version of nginx

Requirements
------------

* Ubuntu Linux
* FreeBSD

Role Variables
--------------

* `nginx_package_name` (default: `nginx`)
  * The name of the nginx package to install

* `nginx_service_name` (default: `nginx`)
  * The name of the nginx service

* `nginx_user` (default: `www` for FreeBSD, `nginx` for Ubuntu)
  * The user that nginx runs as

* `nginx_group` (default: `www` for FreeBSD, `nginx` for Ubuntu)
  * The group that nginx runs as

* `nginx_config_file` (default: `/usr/local/etc/nginx/nginx.conf` for FreeBSD, `/etc/nginx/nginx.conf` for Ubuntu)
  * The main nginx configuration file path

* `nginx_conf_dir` (default: `/usr/local/etc/nginx` for FreeBSD, `/etc/nginx` for Ubuntu)
  * The directory where NGINX configuration files are stored

* `nginx_mime_types_file` (default: `/usr/local/etc/nginx/mime.types` for FreeBSD, `/etc/nginx/mime.types` for Ubuntu)
  * The path to the mime.types file

* `nginx_pid_file` (default: `/var/run/nginx.pid` for FreeBSD, `/run/nginx.pid` for Ubuntu)
  * The path to the nginx PID file

* `nginx_error_log` (default: `/var/log/nginx/error.log`)
  * The path to the nginx error log file

* `nginx_access_log` (default: `/var/log/nginx/access.log`)
  * The path to the nginx access log file

* `nginx_manage_config` (default: `true`)
  * Whether to manage the nginx configuration file

* `nginx_enable_service` (default: `true`)
  * Whether to enable the nginx service to start at boot

* `nginx_start_service` (default: `true`)
  * Whether to start the nginx service

* `running_on_server` (default: `true`)
  * Set to `false` when running in test containers to skip service management

Dependencies
------------

* `community.general` collection (required for FreeBSD `pkgng` and `sysrc` modules)

Example Playbook
----------------

```yaml
- hosts: servers
  roles:
    - role: nginx
      nginx_config_file: /etc/nginx/nginx.conf
      nginx_enable_service: true
```
