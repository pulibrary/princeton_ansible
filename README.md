Princeton Ansible Playbooks
===========================

# Import PUL Box

Place the none tracked `ubuntu-16.04.virtualbox.box` in the `images` directory is an image built from the [https://github.com/pulibrary/vmimages](https://github.com/pulibrary/vmimages) repository. It will need the relatively insecure `pulsys_rsa_key` to log into the VM. Ask for the untracked private key

Import the box with 

```
$ vagrant box add --name princeton_box images/ubuntu-16.04.virtualbox.box
```


# Developing

You can use a vagrant machine to develop and test these ansible playbooks. In
order to do so, run `vagrant up` from this directory.

After the box is built, you can re-run the scripts via `vagrant provision`.

You can ignore the prompt for an SSH password, but will have to put in the
Ansible Vault password.
