# Role Name

Creates or refreshes our firewall deny list.

To add one or more IPs, ranges, etc. to the deny list:

- edit vars/main.yml
- within the banned_ranges variable, add a new entry like this:

banned_ranges:

- name: tencent cloud
  ip_range:
  - 1.12.0.0/15
  - 1.14.0.0/16
- name: other problematic actor
  ip_range:
  - x.xx.x.x/xx
  - y.yy.y.y/yy

## Requirements

DNS registered [at Google Cloud](https://console.cloud.google.com/net-services/dns/zones?referrer=search&project=pul-gcdc)

edit the [files/drop.txt](files/drop.txt) and run the playbook

## Example Playbook

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: username.rolename, x: 42 }

## License

BSD

## Author Information

An optional section for the role authors to include contact information, or a website (HTML is not allowed).
