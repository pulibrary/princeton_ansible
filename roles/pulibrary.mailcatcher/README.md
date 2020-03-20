Role Name
=========

Install the mailcatcher gem into the global ruby

Requirements
------------

NA

Role Variables
--------------

* install_mailcatcher: defaults to false - you must specifically opt into mailcatcher
* mailcatcher_install_location: location mailcatcher will be installed. defaults to /usr/local/bin/mailcatcher If you are utilizing RVM the installation location will change based on your current ruby (e.g. /usr/local/rvm/gems/ruby-2.4.6/bin/mailcatcher)

Dependencies
------------

This is dependant on ruby being installed as is specified in the meta

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables
passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: roles/pulibrary.mailcatcher, x: 42 }

License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
