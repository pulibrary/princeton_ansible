<p align="left">
  <a href="https://github.com/pulibrary/princeton_ansible"><img alt="Princeton Ansible Workflow" src="https://github.com/pulibrary/princeton_ansible/workflows/Molecule%20Tests/badge.svg"></a>
</p>

Princeton Ansible Playbooks
===========================

A collection of roles and playbooks for provisioning and managing the machines that run PUL applications.

# Project Setup for Development and Testing

## First-time setup

Do these things once, after you clone this repo.

### Mac

1. Install homebrew
1. Install [Docker Desktop](https://docs.docker.com/desktop/install/mac-install/)
1. Run `bin/first-time-setup.sh` - this installs all the language and tooling dependencies
1. Run `bin/setup` - this adds a [pre-commit hook](https://github.com/pulibrary/princeton_ansible/blob/main/.githooks/pre-commit) to your environment that will prevent you from accidentally checking in unencrypted vault files.
1. follow the steps under "Every time setup"

### Microsoft Windows/ Ubuntu

 1. Use the [WSL Document](./README_Windows.md)

## Every time setup

Run these commands every time you use this repo

```bash
pipenv sync
pipenv shell
source princeton_ansible_env.sh
lpass login <your-netid@princeton.edu>
```

Now you can run tests (See "Running molecule tests") or playbooks (See "Usage")

## Validate that everything is installed correctly

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

   1. delete the create.yml and destroy.yml files

   1. edit `vi roles/$your_new_role/meta/main.yml` and add a description

   1. edit `vi roles/$your_new_role/molecule/default/converge.yml`
      1. replace `name: Converge` with `name: your_new_role`

1. Test that your role is now working
   All tests should pass

   If you have not created any tasks you might get an error in the `Wait for instance(s) creation to complete` task
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

## Running a playbook

Run a playbook

```bash
ansible-playbook playbooks/example.yml
```

Run a playbook from an error or a specific task

```bash
ansible-playbook playbooks/example.yml --start-at-task="Task Name"
```

## Avoiding downtime

To ensure uptime while provisioning a set of machines, the general process is to remove half the machines from the load balancer, provision and deploy them, then put them back on the load balancer and remove the other half for provisioning and deployment.

2 ways to remove machines from the load balancer:

- Use the capistrano tasks, duplicated to every rails application, called `remove_from_nginx` and `serve_from_nginx` to remove and replace sets of machines.
- [Use the load balancer UI](https://github.com/pulibrary/pul-it-handbook/blob/main/services/nginxplus.md#using-the-admin-ui) to control which boxes are being served.

To run a playbook on only a subset of hosts, use the `--limit` option to `ansible-playbook`, e.g.:

```
ansible-playbook playbooks/figgy_production.yml --limit figgy3.princeton.edu
```

You can also add `--list-hosts` just to check which hosts will be affected before you run.

Make sure to deploy the application to each set of boxes after they are provisioned, to ensure the local webserver is restarted after the environment changes.

To check the newly-provisioned boxes before swapping to the other group, SSH to the box that's off the load balancer and check that the index page still looks okay
`$ curl localhost:80`

Note that some playbooks have separate sections for webservers and workers. Make sure that all the boxes get provisioned.

# Connections to other boxes

Currently there's no automation on firewall changes when the box you're provisioning needs to talk to the postgres or solr machines. See instructions for manual edits at:

- <https://github.com/pulibrary/pul-the-hard-way/blob/master/services/postgresql.md#allow-access-from-a-new-box>
- <https://github.com/pulibrary/pul-the-hard-way/blob/master/services/solr.md#allow-access-from-a-new-box>

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

## Troubleshooting lastpass

More information about lastpass-cli can be found here: <https://lastpass.github.io/lastpass-cli/lpass.1.html>

- If you get the message `[WARNING]: Error in vault password file loading (default): Invalid vault password was provided from script`, it's possible you have vault passwords hanging around from previous projects, and they are overriding the lastpass password. If you no longer need those passwords, remove them. For example:

```bash
rm -rf ~/.vault_pass.txt
rm -rf ~/.ansible-vaults
```

- If you get the message `ERROR! Decryption failed (no vault secrets were found that could decrypt)`, you may still need to source the environment for your shell.

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

   1. Create a PR and commit

## Patching Dependabots

  1. Make recommended changes from dependabot PR run `pipenv install -r
     requirements.txt`

  1. Check in changes to Pipfile.lock

  1. Run the entire test suite locally

  1. Re-run `pipenv lock -r > requirements.txt`
