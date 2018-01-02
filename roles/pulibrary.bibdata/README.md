# Bibdata

This role, and it's complementary playbook, installs all of the necessary components to run a rails server for marc_liberation.

## Installation

- Download the following 64-bit linux Instant Client packages (.zip) from [Oracle](http://www.oracle.com/technetwork/topics/linuxx86-64soft-092277.html):
	- Basic
	- SDK
	- SQL*Plus

- Copy them into the `local_files` directory.

## Development
Create a symbolic link to the bibdata vagrant configuration, then provision a vagrant machine.

```bash
$ ln -s /path/to/thisclonedrepo/Vagrant/bibdataVagrantfile /path/to/thisclonedrepo/Vagrantfile
$ vagrant up
``` 

## Run Playbook

### Staging
```bash
$ ansible-playbook bibdata.yml --limit=bibdata_staging

```

### Production
```bash
$ ansible-playbook bibdata.yml --limit=bibdata_production

```
