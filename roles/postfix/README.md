Role Name
=========

Creates a relay to proofpoint and creates a relay for our applications


Role Variables
--------------

Most use for this role will involve adding your IP address to the allow list with the following variable:

```bash
relay_new_host: 1.2.3.4
postfix_host: "<hostname of pony express>"
```


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
