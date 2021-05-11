Princeton Ansible Playbooks
===========================
<p align="left">
  <a href="https://github.com/pulibrary/princeton_ansible"><img alt="Princeton Ansible Workflow" src="https://github.com/pulibrary/princeton_ansible/workflows/Molecule%20Tests/badge.svg"></a>
</p>

# Setting up your Python Environment

## Install Prerequisites

### MacOS

 * `brew install docker`
 * If using asdf, install the plugins as listed in .tool-versions
 * Otherwise:
  * `brew install python`
  * `brew install pipenv`
  * `brew install rbenv`
 * If you have errors when running pipenv sync in the Setup your Environment
   step below, you may need to update pip within the shell; see
   https://stackoverflow.com/questions/65658570/pipenv-install-fails-on-cryptography-package-disabling-pep-517-processing-is-i/67095614#67095614

### Ubuntu Bionic

 * `sudo add-apt-repository multiverse && sudo apt -y update`
 * `sudo apt -y install python-pip`
 * `sudo apt install apt-transport-https ca-certificates curl software-properties-common`
 * `curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add
   -`
 * `sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"`
 * `sudo apt update`
 * `sudo apt install docker-ce`
```bash
curl https://pyenv.run | bash
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
```

Edit your `~/.bashrc` accordingly

```bash
pyenv install --list
```
From the resulting list select the version of python version that matches the
version in the `Pipfile` in this repo

```bash
pip install --user pipenv
```

Add the docker group to your computer and add your user to this group with:

```bash
sudo groupadd docker
sudo usermod -aG docker $USER
```

You will need to relaunch your shell.


## Setup your environment

**Note: These commands should be run for each shell you run**
```bash
pipenv sync
pipenv shell
```

## Determine if everything is installed correctly

Make sure docker is running before you run the following (from inside the `pipenv shell`) to test the installation:

```bash
cd roles/common
molecule test
```


# Developing

## Create a new role
In all the steps below substitue your role name for `your_new_role`
1. Initialize the role with molecule.
   Run the following command from the root of this repo:

   ```bash
   export your_new_role=<fil in the role name here>
   molecule init role roles/$your_new_role --driver-name docker
   ```
1. Set up to run from github actions `vi .github/workflows/molecule_tests.yml` add for your role at the end matrix of the roles
   ```
       - your_new_role
   ```
1. Setup the directory to run molecule

   1. copy over the root molecule.yml
      ```bash
      cp roles/example/molecule.yml roles/$your_new_role/molecule/default
      cp roles/example/main.yml roles/$your_new_role/meta/main.yml
      cp roles/example/.ansible-lint roles/$your_new_role/.ansible-lint
      ```

   1. edit `vi roles/$your_new_role/meta/main.yml` and add a description

   1. edit `vi roles/$your_new_role/molecule/default/converge.yml`
      1. Add:
         ```
         vars:
           - running_on_server: false
         ```
      1. replace `name: roles/your_new_role` with `name: your_new_role`

1. Test that your role is now working
   All tests should pass
   ```
   cd roles/$your_new_role
   molecule test
   ```
1. Push your branch and verify that circle ci runs and passes.

## Generating Molecule Tests


## Molecule tests

You can run `molecule test` from either the root directory or the role directory (for example roles/example)
If you are writing tests we have found it is easier to test just your examples by running from the role directory.

We also recommend instead of running just `molecule test` which takes a very long time your run `molecule converge` to build a docker container with your ansible playbook loaded.  You can run converge and/or verify as many times as needed to get your playbook working.

```bash
molecule lint
molecule converge
molecule verify
```

If your are having issues with your tests passing and have run `molecule converge` you can connect to the running container by running
```
molecule login
```

# Usage

If you need to run a playbook

```bash
ansible-playbook playbooks/example.yml
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


## SolrCloud Vagrantfile

*Please be aware that the [Vagrantfile for the SolrCloud Role](Vagrant/solrcloudVagrantfile)
is extremely resource intensive and may not provision properly on host machines
lacking adequate hardware resources.*

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
3. `gem install lastpass-ansible`
4. `source princeton_ansible_env.sh`

## Changing/Modifying Passwords

In the event that there is a need to modify the vault password grep recursively to find the occurrence of `AES256` from the root of the repo. I am using the `grep` commands below, YMMV

```bash
grep -RI AES256 .
```

Rekey the password with the following

```bash
ansible-vault rekey /path/to/file/vault.yml
ansible-vault rekey /path/to/file/smb.credentials
ansible-vault rekey /path/to/file/id_rsa
ansible-vault rekey /path/to/file/license.key
ansible-vault rekey /path/to/file/webhost.conf
ansible-vault rekey /path/to/file/webhost_priv.key
```

update the file on lastpass so others can use

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
   
