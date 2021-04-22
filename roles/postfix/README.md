Role Name
=========

This install postfix. Generally we will be setting this out to use a relay
Requirements
------------


Role Variables
--------------

adding
`postfix_relayhost:[lib-ponyexpr.princeton.edu]` in `group_vars/project/` should
be enough for most use cases.

```yaml
---
# defaults file for postfix

# These settings are required in postfix.
postfix_myhostname: "{{ ansible_fqdn }}"
postfix_mydomain: "{{ ansible_domain | default('localdomain', true) }}"
postfix_myorigin: "{{ ansible_domain | default('localdomain', true) }}"

# To "listen" on public interfaces, set inet_interfaces to something like
# "all" or the name of the interface, such as "eth0".
postfix_inet_interfaces: "loopback-only"

# Enable IPv4, and IPv6 if supported - if IPV4 only set to ipv4
postfix_inet_protocols: all

# The distination tells Postfix what mails to accept mail for.
postfix_mydestination: $mydomain, $myhostname, localhost.$mydomain, localhost

# To accept email from other machines, set the mynetworks to something like
# "192.168.0.0/24".
postfix_mynetworks: "127.0.0.0/8"

# These settings change the role of the postfix server to a relay host.
# postfix_relay_domains: "$mydestination"

# If you want to forward emails to another central relay server, set relayhost.
# use brackets to sent to the A-record of the relayhost.
postfix_relayhost: "[relay.example.com]"
```

Dependencies
------------

A list of other roles hosted on Galaxy should go here, plus any details in regards to parameters that may need to be set for other roles, or variables that are used from other roles.

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
