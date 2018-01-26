# Pulmap

This role, and it's complementary playbook, installs all of the necessary components to run a rails server for Pulmap.

## Development
Create a symbolic link to the pulmap vagrant configuration, then provision a vagrant machine.

```bash
$ ln -s /path/to/thisclonedrepo/Vagrant/pulmapVagrantfile /path/to/thisclonedrepo/Vagrantfile
$ vagrant up
``` 

## Run Playbook

### Staging
```bash
$ ansible-playbook pulmap.yml --limit=pulmap
```

### Production
```bash
$ ansible-playbook pulmap.yml --limit=pulmap_staging
```
