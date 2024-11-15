Princeton Ansible Playbooks
===========================
<p align="left">
  <a href="https://github.com/pulibrary/princeton_ansible"><img alt="Princeton Ansible Workflow" src="https://github.com/pulibrary/princeton_ansible/workflows/Molecule%20Tests/badge.svg"></a>
</p>

# Setting up your Python Environment

## First-time basic setup on MacOS

1. Install homebrew
1. Run `bin/first-time-setup.sh`

You can then follow the instructions in the
following sections to run your playbooks:
1. [Setup your environment](#setup-your-environment)
1. [Automatically pull vault password from lastpass](#automatically-pull-vault-password-from-lastpass)
1. [Usage](#usage)

## Install Prerequisites

### MacOS

 1. Install [Docker Desktop](https://docs.docker.com/desktop/install/mac-install/)
 1. Install ruby and python
    1. If using [asdf], install the plugins as listed in .tool-versions
       ```
       asdf install
       pip install pipenv
       ```
       **NOTE** You may encounter an error `include the header <string.h> or explicitly provide a declaration for 'memcmp'`.   Many thanks to folks here for solving this (https://github.com/openssl/openssl/issues/18720#issuecomment-1185940347). Instead run:
       ```
       optflags=-Wno-error=implicit-function-declaration ASDF_RUBY_BUILD_VERSION=v20220630 asdf install
       ```

       **NOTE** You may need to run `asdf plugin-add python`
    1. Otherwise:
       1. `brew install python`
       1. `brew install rbenv`
       1. `brew install pipenv`
 1. If you have errors when running pipenv sync in the Setup your Environment
   step below, you may need to update pip within the shell; see
   https://stackoverflow.com/questions/65658570/pipenv-install-fails-on-cryptography-package-disabling-pep-517-processing-is-i/67095614#67095614


### Microsoft Windows/ Ubuntu

 1. Use the [WSL Document](./README_Windows.md)

## Setup your environment

**Note: These commands should be run for each shell you run**
```bash
bin/setup
pipenv sync
pipenv shell
```

NOTE: The `bin/setup` is very important since it adds a [pre-commit hook](https://github.com/pulibrary/princeton_ansible/blob/main/.githooks/pre-commit) to your environment that will prevent you from accidentally checking in unencrypted vault files.

## Determine if everything is installed correctly

Make sure docker is running before you run the following (from inside the `pipenv shell`) to test the installation:

```bash
cd roles/common
pip3 install 'molecule-plugins[docker]'
molecule test
```


# Developing

## Create a new role
In all the steps below substitute your role name for `your_new_role`
1. Initialize the role with [ansible-galaxy](https://www.redhat.com/sysadmin/developing-ansible-role)
   Run the following command from the root of this repo:

   ```bash
   export your_new_role=<fill in the role name here>
   cd roles/$your_new_role
   molecule init scenario
   cd ../..
   ```
1. Set up to run from github actions `vim .github/workflows/molecule_tests.yml` add for your role at the end matrix of the roles
   ```
       - your_new_role
   ```
1. Setup the directory to run molecule

   1. copy all molecule and lint files (note you need the `.` in the command
      below to get the hidden files)
      ```bash
      cp -r roles/example/* $your_new_role
      ```

   1. edit `vi roles/$your_new_role/meta/main.yml` and add a description

   1. edit `vi roles/$your_new_role/molecule/default/converge.yml`
      1. replace `name: Converge` with `name: your_new_role`

1. Test that your role is now working
   All tests should pass
   ```
   cd roles/$your_new_role
   molecule test
   ```
1. Push your branch and verify that CI runs and passes on GitHub Actions.

1. If the role is related to a new project, add group variables and inventory.
   1. Add a `group_vars/your_new_project` directory and add files with the required variables. Usually this includes `common.yml` for variables that apply in all environments, `vault.yml` for secret values like passwords and keys, and one file per environment (generally at least `production.yml` and `staging.yml`).
   1. Add an `inventory/all_projects/your_new_project` file and list all VMs and other resources. Group them by environment - see any of the existing files for examples.
   1. Add your new groups to the relevant files in the `inventory/by_environment/` directory. For example, add `your_new_project_production` to `inventory/by_environment/production`. Try to keep the lists alphabetized.

## Running Molecule tests

You can run `molecule test` from either the root directory or the role directory (for example roles/example)
If you are writing tests we have found it is easier to test just your examples by running from the role directory.

We also recommend instead of running just `molecule test` which takes a very long time your run `molecule converge` to build a docker container with your ansible playbook loaded.  You can run converge and/or verify as many times as needed to get your playbook working.

```bash
molecule lint
molecule converge
molecule verify
```

If you are having issues with your tests passing and have run `molecule converge` you can connect to the running container by running
```
molecule login
```
## Troubleshooting a container step

If you have a specific task that is not behaving, utilize the tests to run just that step.  This is especially useful for long running `molecule converge`

You basically copy the failing task into the molecule/verify.yml and run verify over and over instead of needing to run the entire converge over and over.  This makes debugging much faster and joyful! 

## Troubleshooting a test run

If you need to ensure you're getting the newest docker image for your local
test run you can do a dance like this to delete your ansible docker machines,
volumes, and images:

```
cd to the role in question
% molecule destroy
% docker ps -qaf ancestor=quay.io/pulibrary/jammy-ansible:latest | xargs docker stop
% docker ps -qaf ancestor=quay.io/pulibrary/jammy-ansible:latest | xargs docker rm
% docker volume ls -qf dangling=true | xargs docker volume rm
% docker rmi quay.io/pulibrary/jammy-ansible
% molecule converge
```

# Usage

If you need to run a playbook

```bash
ansible-playbook playbooks/example.yml
```

Running a playbook from an error or a specific task
```bash
ansible-playbook playbooks/example.yml --start-at-task="Task Name"
```

## Provisioning to a service with multiple hosts (no downtime)

Check to make sure you're going to run on the correct host
`$ ansible-playbook playbooks/figgy_production.yml --limit figgy3.princeton.edu --list-hosts`

coordinate with operations to take the machine off load balancer
run playbook:
`$ ansible-playbook playbooks/figgy_production.yml --limit figgy3.princeton.edu`

capistrano deploy to the box that's off the load balancer.
Make sure you're depoying the already-deployed commit! Note the way to do this
may vary by project in figgy it's the BRANCH env var
`$ bundle exec HOSTS=figgy3 BRANCH=commit_hash cap production deploy`

SSH to the box that's off the load balancer and check that the index page still looks okay
`$ curl localhost:80`
  A bunch of the page only shows up if you're logged in, but you can see the menus and stuff

Tell ops that one's done; switch the load balancer to the other box. Repeat the process.

After both boxes are provisioned, ops puts them back up on the load
balancer

provision the workers:
`$ ansible-playbook playbooks/figgy_production.yml --limit figgy_production_workers`

Some roles don't have the right `become` / sudo settings. (Figgy doesn't have
this problem). the `-b` flag to ansible-playbook will correct these.

how to do a dry run? it's unclear. documentation suggests it's `--check`

Finally, deploy from robots channel to get the new functionality on all the boxes at once

# Connections to other boxes

Currently there's no automation on firewall changes when the box you're provisioning needs to talk to the postgres or solr machines. See instructions for manual edits at:

* https://github.com/pulibrary/pul-the-hard-way/blob/master/services/postgresql.md#allow-access-from-a-new-box
* https://github.com/pulibrary/pul-the-hard-way/blob/master/services/solr.md#allow-access-from-a-new-box

# Vault
Use `ansible-vault edit` to make changes to the `vault.yml` file, for example:

```
ansible-vault edit group_vars/bibdata/vault.yml
```

If you need to diff an ansible-vault file, run
```
git config --global diff.ansible-vault.textconv "ansible-vault view"
git config --local merge.ansible-vault.driver "./ansible-vault-merge %O %A %B %L %P"
git config --local merge.ansible-vault.name "Ansible Vault merge driver"
```
after which any `git diff` command should decrypt your ansible-vault files.

If a file is not decrypting with `git diff` you may need to add the file you're trying to diff to `.gitattributes`.

## Automatically pull vault password from lastpass

  More information about lastpass-cli can be found here: https://lastpass.github.io/lastpass-cli/lpass.1.html
1. `brew install lastpass-cli`
2. `lpass login <email@email.com>`
3. `gem install lastpass-ansible` or `asdf exec gem install lastpass-ansible`
4. `source princeton_ansible_env.sh`

### Troubleshooting lastpass
* If you get the message `[WARNING]: Error in vault password file loading (default): Invalid vault password was provided from script`, it's possible you have vault passwords hanging around from previous projects, and they are overriding the lastpass password. If you no longer need those passwords, remove them. For example:

```bash
rm -rf ~/.vault_pass.txt
rm -rf ~/.ansible-vaults
```
* If you get the message `ERROR! Decryption failed (no vault secrets were found that could decrypt)`, you may still need to source the environment for your shell.
```bash
source princeton_ansible_env.sh
```

### Rekeying the vault

1. Open the `old_vault_password` server in lastpass.  Replace the old vault password with the current ansible vault password.  Add a note to include today's date.
1. Run `pwgen -s 48` to create a new password.
1. Run `ansible-vault rekey --ask-vault-password $(grep -Frl "\$ANSIBLE_VAULT;")`
1. Enter the old vault password
1. Enter the new vault password
1. Run `ansible-vault edit --ask-vault-password` on one of the files you changed (providing the new password), to validate that everything is as it should be.
1. Add the new vault password to the vault_password in lastpass.

## Upgrading Ansible version

   1. In a pipenv shell
      ```bash
      pipenv sync
      pipenv shell
      ```

   1. Upgrade ansible
      ```
      pipenv update ansible
      ```

      If this fails you may need to
      ```
      pipenv uninstall ansible
      pipenv install ansible
      ```

   1. Create the  CI ansible environment
      ```
      pipenv lock -r > requirements.txt
      ```

   1.  Create a PR and commit


## Patching Dependabots

  1. Make recommended changes from dependabot PR run `pipenv install -r
     requirements.txt`

  1. Check in changes to Pipfile.lock

  1. Run the entire test suite locally

  1. Re-run `pipenv lock -r > requirements.txt`
