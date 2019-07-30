Role Name
=========

Install and manage ruby versions using rvm. Bootstrapped from
[https://github.com/rvm/rvm1-ansible](https://github.com/rvm/rvm1-ansible)


Requirements
------------

Ubuntu Bionic

Role Variables
--------------

Below is a list of default values that you can configure:

```yaml
---

# Install 1 or more versions of ruby
# The last ruby listed will be set as the default ruby
rvm1_rubies:
  - 'ruby-2.4.6'

# Install the bundler gem
rvm1_bundler_install: True

# Delete a specific version of ruby (ie. ruby-2.1.0)
rvm1_delete_ruby:

# Install path for rvm (defaults to single user)
# NOTE: If you are doing a ROOT BASED INSTALL then make sure you
#       set the install path to something like '/usr/local/rvm'
rvm1_install_path: '~/.rvm'

# Add or remove any install flags
# NOTE: If you are doing a ROOT BASED INSTALL then
#       make sure you REMOVE the --user-install flag below
rvm1_install_flags: '--auto-dotfiles  --user-install'

# Add additional ruby install flags
rvm1_ruby_install_flags:

# Set the owner for the rvm directory
# NOTE: If you are doing a ROOT BASED INSTALL then
#       make sure you set rvm1_user to 'root'
rvm1_user: 'deploy_user'

# URL for the latest installer script
rvm1_rvm_latest_installer: 'https://raw.githubusercontent.com/rvm/rvm/master/binscripts/rvm-installer'

# rvm version to use
rvm1_rvm_version: 'stable'

# Check and update rvm, disabling this will force rvm to never update
rvm1_rvm_check_for_updates: True

# GPG key verification, use an empty string if you want to skip this
# Note: Unless you know what you're doing, just keep it as is
#           Identity proof: https://keybase.io/mpapis
#           PGP message: https://rvm.io/mpapis.asc
rvm1_gpg_keys: '409B6B1796C275462A1703113804BB82D39DC0E3'

# The GPG key server
rvm1_gpg_key_server: 'hkp://pool.sks-keyservers.net'

# autolib mode, see https://rvm.io/rvm/autolibs
rvm1_autolib_mode: 3
```

Dependencies
------------


Example Playbook
----------------

```yaml
---

- name: Configure servers with ruby support for single user
  hosts: all

  roles:
    - { role: rvm.ruby,
        tags: ruby,
        rvm1_rubies: ['ruby-2.4.6'],
        rvm1_user: 'ubuntu'
      }
```

If you need to pass a list of ruby versions, pass it in an array like so.

```yaml
---
- name: Configure servers with ruby support system wide
  hosts: all
  roles:
    - { role: rvm.ruby,
        tags: ruby,
        become: yes,

        rvm1_rubies: ['ruby-2.2.5','ruby-2.3.1'],
        rvm1_install_flags: '--auto-dotfiles',     # Remove --user-install from defaults
        rvm1_install_path: /usr/local/rvm,         # Set to system location
        rvm1_user: root                            # Need root account to access system location
      }
```
_rvm_rubies must be specified via `ruby-x.x.x` so that if you want_
_ruby 2.2.5, you will need to pass in an array **rvm_rubies: ['ruby-2.2.5']**_


#### System wide installation

The above example would setup ruby system wide. It's very important that you run the
play as root because it will need to write to a system location specified by rvm1_install_path

#### To the same user as `ansible_user`

In this case, just overwrite `rvm_install_path` and by default is set the `--user-install` flag:

```yaml
rvm1_install_flags: '--auto-dotfiles --user-install'
rvm1_install_path: '/home/{{ ansible_user }}/.rvm'
```

#### To a user that is not `ansible_user`

You **will need root access here** because you will be writing outside the ansible
user's home directory. Other than that it's the same as above, except you will
supply a different user account:

```yaml
rvm1_install_flags: '--auto-dotfiles --user-install'
rvm1_install_path: '/home/someuser/.rvm'
```

#### A quick note about `rvm1_user`

In some cases you may want the rvm folder and its files to be owned by a specific
user instead of root. Simply set `rvm1_user: 'foo'` and when ruby gets installed
it will ensure that `foo` owns the rvm directory.

## Upgrading and removing old versions of ruby

A common work flow for upgrading your ruby version would be:

1. Install the new version
2. Run your application role so that bundle install re-installs your gems
3. Delete the previous version of ruby

### Leverage ansible's `--extra-vars`

Just add `--extra-vars 'rvm1_delete_ruby=ruby-2.1.0'` to the end of your play book command and that version will be removed.

License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
