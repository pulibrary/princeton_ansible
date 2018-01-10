Princeton Ansible Playbooks
===========================

# Import PUL Box

Download 'ubuntu-16.04.virtualbox.box` from the google drive and place it in the `images` directory. It is an image built from the [https://github.com/pulibrary/vmimages](https://github.com/pulibrary/vmimages) repository. It will need the relatively insecure `pulsys_rsa_key` to log into the VM. Ask for the untracked private key.

Import the box with 

```
$ vagrant box add --name princeton_box images/ubuntu-16.04.virtualbox.box
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

# Connections to other boxes

Currently there's no automation on firewall changes when the box you're provisioning needs to talk to the postgres or solr machines. See instructions for manual edits at:

* https://github.com/pulibrary/pul-the-hard-way/blob/master/services/postgresql.md#allow-access-from-a-new-box
* https://github.com/pulibrary/pul-the-hard-way/blob/master/services/solr.md#allow-access-from-a-new-box
