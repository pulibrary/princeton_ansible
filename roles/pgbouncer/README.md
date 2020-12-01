Role Name
=========

A role that installs [pgbouncer](https://www.pgbouncer.org/) the connection pooler for postgresql. 

Requirements
------------

A virtual machine instance with postgresql installed from `pulibrary.psql` that this will pool connections to

Role Variables
--------------

find any variables in `defaults/main.yml`, `vars/main.yml` pay special attention to `pgbouncer_auth_users`

### pgbouncer_auth_users

This is a list of dict objects which each have a **name** and a *password* property. For this example I will use a plaintext password. 

```yml
pgbouncer_auth_users:
  - name: postgres
    password: pa55word
```

The above will result in a userlist.txt file that looks like this:

```
"postgres" "pa55word"
```
We don't use simple passwords however. 

#### Configuring userlist.txt

Here we're using the md5 scheme, where the md5 password is just the md5sum of `password + username` with the string `md5` prepended. For instance, to derive the hash for user  user `pgbouncer_user` with password `Sup4rH4ck0r5`, you can do:

```bash
# ubuntu, debian, etc.
echo -n "Sup4rH4ck0r5pgbouncer_user" | md5sum
# macOS, openBSD, etc.
md5 -s "Sup4rH4ck0r5pgbouncer_user"
```

Then just add `md5` to the beginning of that. Put the result of that in the [group_vars/postgresql/vault.yml](group_vars/postgresql/vault.yml) which will show up in the `userlist.txt` file on the server looking like this when decrypted looking like this:

```ini
"pbbouncer_user" "md5c1c4c3b38e45d23638e84e349da62898"
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
