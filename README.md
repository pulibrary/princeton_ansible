<p align="left">
  <a href="https://github.com/pulibrary/princeton_ansible"><img alt="Princeton Ansible Workflow" src="https://github.com/pulibrary/princeton_ansible/workflows/Molecule%20Tests/badge.svg"></a>
</p>

Princeton Ansible Playbooks
===========================

A collection of roles and playbooks for provisioning and managing the machines that run PUL applications.

Project Setup for Development and Testing
-----------------------------------------

First-time setup
----------------

Do these things once, after you clone this repo.

### Mac

1. Install [Docker Desktop](https://docs.docker.com/desktop/install/mac-install/)
2. Run `bin/first-time-setup.sh` - this installs Devbox and all language/tooling dependencies
3. If you encounter Nix build user errors, run: `./fix-nix-build-users.sh`
4. Follow the steps under "Every time setup"

### Microsoft Windows/ Ubuntu

1. Use the [WSL Document](./README_Windows.md)

### Linux

1. Install Docker
2. Run `bin/first-time-setup.sh` - this installs Devbox and all dependencies
3. Follow the steps under "Every time setup"

Every time setup
----------------

Run these commands every time you use this repo:

```bash
# Enter the Devbox development environment
devbox shell

# Initialize the Python environment (first time in new shell)
devbox run init

# Login to LastPass
lpass login <your-netid@princeton.edu>
```

The Devbox environment provides:

- Python virtual environment with all Ansible tools
- ANSIBLE_VAULT_PASSWORD_FILE configured to use lastpass-ansible
- Git hooks to prevent committing unencrypted vault files
- LPASS_AGENT_TIMEOUT set to 9 hours

Now you can run tests (See "Running molecule tests") or playbooks (See "Usage")

Validate that everything is installed correctly
-----------------------------------------------

Make sure Docker is running, then from inside the Devbox shell:

```bash
# Verify tools are available
ansible --version
molecule --version

# Check environment configuration
devbox run env-info

# Run a test
cd roles/common
env -u ANSIBLE_VAULT_IDENTITY_LIST -u ANSIBLE_VAULT_PASSWORD_FILE molecule test
```

Troubleshooting Setup
---------------------

### Ansible Command Not Found / Reinstall deps

If `ansible` or other Python tools aren't found in your Devbox shell (e.g. a fresh clone):

```bash
# Exit and re-enter devbox shell
exit
devbox shell
devbox run init
```

### LastPass Authentication Issues

If you get vault password errors when running playbooks:

1. Ensure you're logged into LastPass:

   ```bash
   lpass status
   ```

2. If not logged in:

   ```bash
   lpass login <your-netid@princeton.edu>
   ```

3. Verify the vault configuration is set:

   ```bash
   devbox run env-info
   ```

Available Helper Scripts
------------------------

Inside the Devbox shell, you can run:

| Command | Description |
|---------|-------------|
| `devbox run init` | Initialize Python environment and dependencies |
| `devbox run update-deps` | Update Python dependencies from requirements.txt |
| `devbox run clean` | Remove virtual environment and Devbox cache |
| `devbox run test` | Verify Ansible tools installation |
| `devbox run env-info` | Display current environment configuration |

Developing
----------

Create a new role
-----------------

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

   ```text
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

   ```text
   cd roles/$your_new_role
   env -u ANSIBLE_VAULT_IDENTITY_LIST -u ANSIBLE_VAULT_PASSWORD_FILE molecule test
   ```

1. Push your branch and verify that CI runs and passes on GitHub Actions.

1. If the role is related to a new project, add group variables and inventory.
   1. Add a `group_vars/your_new_project` directory and add files with the required variables. Usually this includes `common.yml` for variables that apply in all environments, `vault.yml` for secret values like passwords and keys, and one file per environment (generally at least `production.yml` and `staging.yml`).
   1. Add an `inventory/all_projects/your_new_project` file and list all VMs and other resources. Group them by environment - see any of the existing files for examples.
   1. Add your new groups to the relevant files in the `inventory/by_environment/` directory. For example, add `your_new_project_production` to `inventory/by_environment/production`. Try to keep the lists alphabetized.

Running Molecule tests
----------------------

Molecule tests should be run without vault configuration to avoid requiring production passwords for testing. Always unset the vault environment variables when running molecule:

```bash
cd roles/example
env -u ANSIBLE_VAULT_IDENTITY_LIST -u ANSIBLE_VAULT_PASSWORD_FILE molecule test
```

You can run individual molecule commands for faster development:

```bash
# Run these with vault variables unset
env -u ANSIBLE_VAULT_IDENTITY_LIST -u ANSIBLE_VAULT_PASSWORD_FILE molecule lint
env -u ANSIBLE_VAULT_IDENTITY_LIST -u ANSIBLE_VAULT_PASSWORD_FILE molecule converge
env -u ANSIBLE_VAULT_IDENTITY_LIST -u ANSIBLE_VAULT_PASSWORD_FILE molecule verify
```

If you are having issues with your tests passing and have run `molecule converge` you can connect to the running container by running:

```text
env -u ANSIBLE_VAULT_IDENTITY_LIST -u ANSIBLE_VAULT_PASSWORD_FILE molecule login
```

Troubleshooting a container step
--------------------------------

If you have a specific task that is not behaving, utilize the tests to run just that step. This is especially useful for long running `molecule converge`

You basically copy the failing task into the molecule/verify.yml and run verify over and over instead of needing to run the entire converge over and over. This makes debugging much faster and joyful!

Troubleshooting a test run
--------------------------

If you need to ensure you're getting the newest docker image for your local
test run you can do a dance like this to delete your ansible docker machines,
volumes, and images:

```text
cd to the role in question
% env -u ANSIBLE_VAULT_IDENTITY_LIST -u ANSIBLE_VAULT_PASSWORD_FILE molecule destroy
% docker ps -qaf ancestor=quay.io/pulibrary/jammy-ansible:latest | xargs docker stop
% docker ps -qaf ancestor=quay.io/pulibrary/jammy-ansible:latest | xargs docker rm
% docker volume ls -qf dangling=true | xargs docker volume rm
% docker rmi quay.io/pulibrary/jammy-ansible
% env -u ANSIBLE_VAULT_IDENTITY_LIST -u ANSIBLE_VAULT_PASSWORD_FILE molecule converge
```

Usage
-----

Running a playbook
------------------

Run a playbook (requires LastPass login for vault access):

```bash
ansible-playbook playbooks/example.yml
```

Run a playbook from an error or a specific task:

```bash
ansible-playbook playbooks/example.yml --start-at-task="Task Name"
```

Avoiding downtime
-----------------

To ensure uptime while provisioning a set of machines, the general process is to remove half the machines from the load balancer, provision and deploy them, then put them back on the load balancer and remove the other half for provisioning and deployment.

2 ways to remove machines from the load balancer:

- Use the capistrano tasks, duplicated to every rails application, called `remove_from_nginx` and `serve_from_nginx` to remove and replace sets of machines.
- [Use the load balancer UI](https://github.com/pulibrary/pul-it-handbook/blob/main/services/nginxplus.md#using-the-admin-ui) to control which boxes are being served.

To run a playbook on only a subset of hosts, use the `--limit` option to `ansible-playbook`, e.g.:

```text
ansible-playbook playbooks/figgy_production.yml --limit figgy3.princeton.edu
```

You can also add `--list-hosts` just to check which hosts will be affected before you run.

Make sure to deploy the application to each set of boxes after they are provisioned, to ensure the local webserver is restarted after the environment changes.

To check the newly-provisioned boxes before swapping to the other group, SSH to the box that's off the load balancer and check that the index page still looks okay
`$ curl localhost:80`

Note that some playbooks have separate sections for webservers and workers. Make sure that all the boxes get provisioned.

Connections to other boxes
--------------------------

Currently there's no automation on firewall changes when the box you're provisioning needs to talk to the postgres or solr machines. See instructions for manual edits at:

- <https://github.com/pulibrary/pul-the-hard-way/blob/master/services/postgresql.md#allow-access-from-a-new-box>
- <https://github.com/pulibrary/pul-the-hard-way/blob/master/services/solr.md#allow-access-from-a-new-box>

Vault
-----

Use `ansible-vault edit` to make changes to the `vault.yml` file, for example:

```text
ansible-vault edit group_vars/bibdata/vault.yml
```

If you need to diff an ansible-vault file, run

```text
git config --global diff.ansible-vault.textconv "ansible-vault view"
git config --local merge.ansible-vault.driver "./ansible-vault-merge %O %A %B %L %P"
git config --local merge.ansible-vault.name "Ansible Vault merge driver"
```

after which any `git diff` command should decrypt your ansible-vault files.

If a file is not decrypting with `git diff` you may need to add the file you're trying to diff to `.gitattributes`.

Troubleshooting lastpass
------------------------

More information about lastpass-cli can be found here: <https://lastpass.github.io/lastpass-cli/lpass.1.html>

- If you get the message `[WARNING]: Error in vault password file loading (default): Invalid vault password was provided from script`, it's possible you have vault passwords hanging around from previous projects, and they are overriding the lastpass password. If you no longer need those passwords, remove them. For example:

```bash
rm -rf ~/.vault_pass.txt
rm -rf ~/.ansible-vaults
```

- If you get the message `ERROR! Decryption failed (no vault secrets were found that could decrypt)`, verify that you're logged into LastPass and the environment is configured:

```bash
lpass status  # Should show logged in
devbox run env-info  # Should show ANSIBLE_VAULT_PASSWORD_FILE set
```

### Rekeying the vault

1. Open the `old_vault_password` server in lastpass. Replace the old vault password with the current ansible vault password. Add a note to include today's date.
1. Run `pwgen -s 48` to create a new password.
1. Run `ansible-vault rekey --ask-vault-password $(grep -Frl "\$ANSIBLE_VAULT;")`
1. Enter the old vault password
1. Enter the new vault password
1. Run `ansible-vault edit --ask-vault-password` on one of the files you changed (providing the new password), to validate that everything is as it should be.
1. Add the new vault password to the vault_password in lastpass.
1. Log into [Ansible Tower](https://ansible-tower.princeton.edu/#/credentials/10/details). To replace it click `Edit` then click on the circular arrow to the left of the Vault Password, paste in the new value, and save. The value is automatically encrypted.

Upgrading Ansible version
-------------------------

1. Edit `requirements.txt` to update the ansible version
2. In Devbox shell, update the dependencies:

   ```bash
   devbox run update-deps
   ```

3. Verify the new version:

   ```bash
   ansible --version
   ```

4. Run the test suite to ensure compatibility
5. Commit the updated `requirements.txt`

Migration from Pipenv to Devbox
-------------------------------

This project has been migrated from Pipenv to Devbox for better reproducibility and cross-platform support. Key changes:

| Feature | Old (Pipenv/ASDF) | New (Devbox) |
|---------|-------------------|--------------|
| **Config File** | `Pipfile`, `.tool-versions` | `devbox.json` |
| **Python Deps** | `Pipfile.lock` | `requirements.txt` + venv |
| **Environment Setup** | `pipenv shell` + source script | `devbox shell` + `devbox run init` |
| **Version Management** | ASDF plugins | Nix packages |
| **LastPass CLI** | Homebrew (macOS only) | Nix package (cross-platform) |

### Files Changed

- **Added**: `devbox.json`, `devbox.lock`, `bin/lastpass-ansible`
- **Removed**: `Pipfile`, `Pipfile.lock`, `.mise.local.toml`
- **Updated**: `bin/first-time-setup.sh`, this README

### For CI/CD

The `requirements.txt` file is maintained for CI/CD compatibility and contains all Python dependencies.
