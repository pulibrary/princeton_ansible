Role Name
=========

Install [docker-ce](https://docs.docker.com/) and [docker-compose](https://github.com/docker/compose)

Requirements
------------

The role targets Ubuntu on the `x86_64` architecture


Role Variables
--------------

Rarely changing ones in the `vars/main.yml`
docker_compose_version: "<version number>"

Dependencies
------------


Example Playbook
----------------

Including an example of how to use your role (for instance, with variables
passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: roles/pulibrary.docker_ce, x: 42 }

License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
