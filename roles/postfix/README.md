Role Name
=========

Creates a relay to proofpoint and creates a relay for our applications


Role Variables
--------------

Most use for this role will involve adding your IP address to the allow list of our relay. Edit the [vars/main.yml](vars/main.yml)

Add the IP address of your VM under `postfix_relay_hosts_addresses:`

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
