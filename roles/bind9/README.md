bind9
=====

Installs `named` (BIND 9) as a local caching resolver and keeps it on IPv4.

Our network does not route IPv6, so a resolver that tries IPv6 first spends
its time waiting for AAAA lookups to time out before falling back to A
records. That shows up as slow name resolution and intermittent resolution
errors. This role pins `named` to IPv4 in two places:

- `OPTIONS="-u bind -4"` in `/etc/default/named`, so the daemon never opens
  IPv6 sockets or sends queries over IPv6.
- `listen-on-v6 { none; };` in `/etc/bind/named.conf.options`.

It also gives `named` something to do: it forwards to the campus resolvers,
caches the answers, and points `/etc/resolv.conf` at itself. The campus
resolvers stay in `/etc/resolv.conf` as fallbacks so that a `named` outage
cannot take DNS on the host down with it.

Requirements
------------

Ubuntu 20.04 or newer, with systemd.

Role Variables
--------------

| Variable | Default | Purpose |
| --- | --- | --- |
| `bind9_ipv4_only` | `true` | Pin `named` to IPv4 for listening and queries. |
| `bind9_named_options` | `-u bind -4` | Startup options written to `/etc/default/named`. |
| `bind9_forwarders` | campus resolvers | Upstream resolvers `named` forwards to. |
| `bind9_forward_policy` | `only` | `only` never falls back to full recursion; `first` does. |
| `bind9_listen_on` | `[127.0.0.1]` | Addresses `named` answers on. |
| `bind9_allow_query` | `[localhost]` | Who may query this resolver. |
| `bind9_recursion` | `true` | Answer recursive queries. |
| `bind9_dnssec_validation` | `auto` | DNSSEC validation mode. |
| `bind9_manage_resolv_conf` | `true` | Let this role own `/etc/resolv.conf`. |
| `bind9_resolver_address` | `127.0.0.1` | Address written first in `/etc/resolv.conf`. |
| `bind9_resolv_search` | host domain | `search` domains for `/etc/resolv.conf`. |
| `running_on_server` | `false` | Skip service and `resolv.conf` changes in containers. |

`/etc/resolv.conf` is only touched when `running_on_server` is true, because
containers do not allow it.

Dependencies
------------

This role depends on `common`.

Example Playbook
----------------

```yaml
- hosts: servers
  roles:
    - role: bind9
```

Allowing other hosts on the subnet to use this resolver:

```yaml
- hosts: servers
  roles:
    - role: bind9
      vars:
        bind9_listen_on:
          - 127.0.0.1
          - "{{ ansible_default_ipv4.address }}"
        bind9_allow_query:
          - localhost
          - 128.112.0.0/16
```

License
-------

MIT

Author Information
------------------

Princeton University Library
