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
| `bind9_config_includes` | `[]` | Additional caller-managed configuration files to include. |
| `bind9_remove_dnsmasq` | `false` | Stop and remove dnsmasq before BIND claims port 53. |
| `bind9_manage_resolv_conf` | `true` | Let this role own `/etc/resolv.conf`. |
| `bind9_resolver_address` | `127.0.0.1` | Address written first in `/etc/resolv.conf`. |
| `bind9_resolv_search` | host domain | `search` domains for `/etc/resolv.conf`. |
| `running_on_server` | `false` | Skip `/etc/resolv.conf` changes in containers. |

`/etc/resolv.conf` is only touched when `running_on_server` is true. Docker
bind-mounts its generated resolver file into containers, so Ansible cannot
atomically replace it during Molecule tests.

DNS cache lifetime and reset
----------------------------

This role does not override BIND's cache TTL settings. Each cached answer
has its own expiry; there is no single interval that clears the entire cache.
The BIND 9.18 defaults are:

| Answer type | Cache lifetime |
| --- | --- |
| Positive answers (such as A, AAAA, and CNAME records) | The TTL received from the upstream resolver, capped by `max-cache-ttl`: 604800 seconds (7 days). |
| Negative answers (NXDOMAIN or no records of the requested type) | The negative TTL derived from the zone's SOA record, capped by `max-ncache-ttl`: 10800 seconds (3 hours). |

These are maximums, not fixed retention periods. For example, an answer
received with a TTL of 300 seconds normally expires after five minutes.
A campus resolver may return a partially elapsed TTL from its own cache.
The role does not enable serving expired answers.

See the [BIND cache settings reference](https://bind9.readthedocs.io/en/stable/reference.html#namedconf-statement-max-cache-ttl).
Check `named -V` when troubleshooting a host running a different BIND version.

### Inspect the remaining TTL

Query the local resolver directly on the affected host (`dig` is provided
by Ubuntu's `dnsutils` package):

```bash
dig @127.0.0.1 lib-solr9-prod.princeton.edu A +noall +answer
```

The second column is the remaining TTL in seconds. Repeat the query to
observe it counting down; a refreshed answer can increase the TTL.
For a negative response, include the status and SOA record:

```bash
dig @127.0.0.1 lib-solr9-prod.princeton.edu A +noall +comments +answer +authority
```

### Clear the local cache

Run one of these commands on the affected host. Start with the smallest
scope needed:

```bash
# Clear all cached record types for one name, including negative answers.
sudo rndc flushname lib-solr9-prod.princeton.edu

# Clear a domain and every name beneath it.
sudo rndc flushtree lib.princeton.edu

# Clear the entire local BIND cache.
sudo rndc flush
```

These commands leave `named` running. Subsequent queries refill the cache.
For aliases, clear the CNAME target as well if its address changed.
See the [BIND rndc reference](https://bind9.readthedocs.io/en/v9.18.39/manpages.html#rndc-name-server-control-utility).

Verify resolution afterward:

```bash
dig @127.0.0.1 lib-solr9-prod.princeton.edu A +noall +answer
```

Flushing affects only this host's BIND cache. Campus forwarders may still
return an old answer until their TTL expires; compare with a direct query:

```bash
dig @128.112.129.209 lib-solr9-prod.princeton.edu A +noall +answer
```

Applications can also maintain their own DNS caches. `resolvectl flush-caches`
clears systemd-resolved's cache, not BIND's cache. A BIND restart is unnecessary
for routine cache clearing.

Additional configuration
------------------------

Callers can use `bind9_config_includes` to include configuration files they
manage. The `pul_nomad` role owns its Consul forwarding zone and passes that
file to this role for inclusion.

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
