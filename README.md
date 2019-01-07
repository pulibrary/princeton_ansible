Princeton Ansible Playbooks
===========================

# Import PUL Box

Download 'ubuntu-16.04.virtualbox.box` from the google drive and place it in the `images` directory. It is an image built from the [https://github.com/pulibrary/vmimages](https://github.com/pulibrary/vmimages) repository. It will need the relatively insecure `pulsys_rsa_key` to log into the VM. Ask for the untracked private key.

Import the box with

```
$ vagrant box add --name princeton_box images/ubuntu-16.04.virtualbox.box
```

# Setting up your Python Environment

## Prerequisites of MacOS

 * `brew install virtualbox`
 * `brew install vagrant`
 * `brew install pyenv`
 * `brew install pyenv-virtualenv`

## Prerequisites of Ubuntu Bionic

 * `sudo add-apt-repository multiverse && sudo apt -y update`
 * `sudo apt -y install virtualbox`
 * `sudo apt-get install vagrant`
 * `git clone https://github.com/pyenv/pyenv.git ~/.pyenv`
```bash
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
echo -e 'if command -v pyenv 1>/dev/null 2>&1; then\n  eval "$(pyenv init -)"\nfi' >> ~/.bashrc
exec "$SHELL"
```
 * `git clone https://github.com/pyenv/pyenv-virtualenv.git $(pyenv
   root)/plugins/pyenv-virtualenv`
```bash
 `echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bash_profile`
```


## Setup your environment

To setup your virtual environment install the current version of Python using
the following command:

`pyenv install 3.7.1`

Create a virtual environment of the Python version you just installed using:

`pyenv virtualenv 3.7.1 princeton_ansible-3.7.1`

This will create a virtualenv based on Python 3.7.1 under $(pyenv root)/versions
in a directory called `princeton_ansible-3.7.1`

Activate your environment using the following command

`pyenv activate princeton_ansible-3.7.1`

Then install all the required packages for this repo by running:

`pip install -r requirements.txt`

Run the following to test

```bash
molecule test
```


# Developing

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

You can ignore the prompt for an SSH password, but will have to put in the
Ansible Vault password.

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
