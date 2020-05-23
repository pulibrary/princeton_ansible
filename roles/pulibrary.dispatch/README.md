Role Name
=========

Installs [dispatch](https://hawkins.gitbook.io/dispatch/)

Requirements
------------


Role Variables
--------------

Variables are in `defaults/main.yml`
slack_app_name: "<the name of your slack bot>" # default is omitted
slack_app_bot_token: "< the token of your bot above>" # default is omitted
slack_app_secret: "< the secret of your bot above>" # default is omitted

Dependencies
------------

It depends on `pulibrary.docker_ce`

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables
passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: roles/pulibrary.dispatch, x: 42 }

License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
