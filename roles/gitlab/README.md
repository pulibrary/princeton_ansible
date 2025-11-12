Role Name
=========

Installs and configures [Gitlab CE](https://about.gitlab.com/install/#ubuntu)
Requirements
------------

Role Variables
--------------

```bash
gitlab_trusted_proxies: "'172.20.80.13', '172.20.80.14', '172.20.80.19'"
gitlab_loadbalancer_domain_name: "git-{{ environment }}.lib.princeton.edu"
```

BSD

An optional section for the role authors to include contact information, or a website (HTML is not allowed).
