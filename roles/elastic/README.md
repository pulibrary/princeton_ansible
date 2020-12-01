Role Name
=========

A role to install Elasticsearch

Requirements
------------

It needs the `pulibrary.openjdk` roles to run

Role Variables
--------------

```bash
elasticsearch_version: "6.x"

elasticsearch_service_state: started
elasticsearch_service_enabled: true

elasticsearch_network_host: localhost
elasticsearch_http_port: 9200
```

Dependencies
------------

* `pulibrary.openjdk`

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables
passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: roles/pulibrary.elastic, x: 42 }

License
-------

MIT

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
