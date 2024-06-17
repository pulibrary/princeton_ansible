Postfix
=======

Creates a relay to proofpoint and creates a relay for our applications

Usage
-----
The most common use of this role will involve adding your IP address to the allow list of our relay. Edit [vars/main.yml](vars/main.yml) and add the IP address of your VM under `postfix_relay_hosts_addresses:`.

Then run https://github.com/pulibrary/princeton_ansible/blob/main/playbooks/postfix.yml according to its commented documentation.

License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a website (HTML is not allowed).
