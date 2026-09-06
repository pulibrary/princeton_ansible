Role Name
=========

This role installs Apache on Ubuntu

Requirements
------------

None

Role Variables
--------------

```
apache:
  docroot: "/var/www/html"

```

JSON access logging
-------------------

Apache normally writes one line of text per request, which a log shipper has to
pick apart with a regex that breaks whenever a user agent or referrer contains a
quote. Turning this on makes Apache record each request as a JSON object
instead, so SigNoz receives real fields and the status, response size and
duration arrive as numbers that can be sorted and charted:

```yaml
apache_json_access_log: true
```

While it is on:

* requests are written to `/var/log/apache2/access_json.log`, which the
  distribution's existing logrotate rule for Apache already covers
* the text access log it replaces (`other_vhosts_access.log`) is turned off, so
  no request is recorded twice
* the managed site file is kept up to date, because a site that carries its own
  access log ignores the one the server defines

Anything reading the old text log, such as a Datadog file check, has to be
pointed at the new path.

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables
passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: apache2, x: 42 }

License
-------

MIT

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
