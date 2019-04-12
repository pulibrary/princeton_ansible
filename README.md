Princeton Ansible Playbooks
===========================

# Import PUL Box

Download `ubuntu-16.04.virtualbox.box` from the google drive and place it in the `images` directory. It is an image built from the [https://github.com/pulibrary/vmimages](https://github.com/pulibrary/vmimages) repository. It will need the relatively insecure `pulsys_rsa_key` to log into the VM. Ask for the untracked private key.

Import the box with

```
$ vagrant box add --name princeton_box images/ubuntu-16.04.virtualbox.box
```

# Setting up your Python Environment

## Prerequisites of MacOS

 * `brew cask install virtualbox`
 * `brew cask install vagrant`
 * `brew install python`
 * `brew install pipenv`
 * `brew install docker`

## Prerequisites of Ubuntu Bionic

 * `sudo add-apt-repository multiverse && sudo apt -y update`
 * `sudo apt -y install virtualbox`
 * `sudo apt -y install vagrant`
 * `sudo apt -y install python-pip`
 * `sudo apt install apt-transport-https ca-certificates curl software-properties-common`
 * `curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add
   -`
 * `sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"`
 * `sudo apt update`
 * `sudo apt install docker-ce`
```bash
curl https://pyenv.run | bash
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

```bash
pipenv sync
pipenv shell
```


Make sure docker is running before you run the following to test

```bash
molecule test
```


# Developing

## Create a new role

Run the following command from the root of this repo:

```bash
molecule init role -r roles/pulibrary.example
```

When you are done add

```bash
- role: pulibrary.example
```

to [`molecule/default/playbooks.yml`](molecule/default/playbooks.yml)


Depending on what project you are working on there are example Vagrantfile's in
the `Vagrant` directory. If you are working on the lae project as an example
create a symbolic link to it with

```
ln -s /path/to/thisclonedrepo/Vagrant/laeVagrantfile
/path/to/thisclonedrepo/Vagrantfile
```

You can use a vagrant machine to develop and test these ansible playbooks. In
order to do so, run `vagrant up` from this directory.

After the box is built, you can re-run the scripts via `vagrant provision`.

You will need to enter the Ansible Vault password.

# Usage

If you need to run a playbook

```bash
ansible-playbook playbooks/example.yml
```

## Provisioning to a service with multiple hosts (no downtime)

Check to make sure you're going to run on the correct host
`$ ansible-playbook playbooks/figgy_production.yml --limit figgy2.princeton.edu --list-hosts`

coordinate with operations to take the machine off load balancer
run playbook:
`$ ansible-playbook playbooks/figgy_production.yml --limit figgy2.princeton.edu`

capistrano deploy to the box that's off the load balancer.
Make sure you're depoying the already-deployed commit! Note the way to do this
may vary by project in figgy it's the BRANCH env var
`$ bundle exec HOSTS=figgy2 BRANCH=commit_hash cap production deploy`

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

If you need to diff an ansible-vault file, run
```
git config --global diff.ansible-vault.textconv "ansible-vault view"
git config --local merge.ansible-vault.driver "./ansible-vault-merge %O %A %B %L %P"
git config --local merge.ansible-vault.name "Ansible Vault merge driver"
```
after which any `git diff` command should decrypt your ansible-vault files.

# Connections to other boxes

Currently there's no automation on firewall changes when the box you're provisioning needs to talk to the postgres or solr machines. See instructions for manual edits at:

* https://github.com/pulibrary/pul-the-hard-way/blob/master/services/postgresql.md#allow-access-from-a-new-box
* https://github.com/pulibrary/pul-the-hard-way/blob/master/services/solr.md#allow-access-from-a-new-box

# Automatically pull vault password from lastpass
1. `brew install lastpass-cli`
2. `lpass login <email@email.com>`
3. `gem install lastpass-ansible`
4. ``export ANSIBLE_VAULT_PASSWORD_FILE=`command -v lastpass-ansible```
