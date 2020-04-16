Role Name
=========

A role that installs [pgbouncer](https://www.pgbouncer.org/) the connection pooler for postgresql

Requirements
------------

An instance of `pulibrary.psql` that this will pool connections to

Role Variables
--------------

find any variables in `defaults/main.yml`, `vars/main.yml` pay special attention to `pgbouncer_auth_users`

### pgbouncer_auth_users

This is a list of dict objects which each have a **name** and a *password* property. You may use a plaintext or encrypted password. 
```yml
pgbouncer_auth_users:
  - name: postgres
    password: pa55word
```
The above will result in a userlist.txt file that looks like this:
```
"postgres" "pa55word"
```

Dependencies
------------


Example Playbook
----------------

There is an example playbook at `molecule/defaults/playbook.yml`


License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
