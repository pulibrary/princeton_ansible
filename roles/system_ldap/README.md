Role Name
=========

Configures an endpoint to use [SSSD](https://ubuntu.com/server/docs/service-sssd) to connect to Princeton Active Directory

Requirements
------------

One will need access to [OIT AD Machine Registration Tool](https://tools.princeton.edu/Dept/) This allows you to register a new name for AD

When the playbook is run the first time add the following manual steps.

```zsh
sudo realm discover pu.win.princeton.edu
sudo realm join -U doas-libsftp pu.win.princeton.edu  
```

The password for the step above can be found by:

```zsh
lpass ls | grep doas-libsftp
```

Enable mkhomedir with the steps below:

```zsh
sudo bash -c "cat > /usr/share/pam-configs/mkhomedir" <<EOF
Name: activate mkhomedir
Default: yes
Priority: 900
Session-Type: Additional
Session:
        required                        pam_mkhomedir.so umask=0022 skel=/etc/skel
EOF
```
Then activate with

```zsh
sudo pam-auth-update
```


Role Variables
--------------


Dependencies
------------

- [roles/common](roles/common)

Example Playbook
----------------

To allow a new user to log in run 

```zsh

```
    - hosts: servers
      roles:
         - { role: username.rolename, x: 42 }

License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a website (HTML is not allowed).
