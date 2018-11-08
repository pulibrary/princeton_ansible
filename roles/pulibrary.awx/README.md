# Ansible Role: AWX (open source Ansible Tower)

Installs and configures [AWX](https://github.com/ansible/awx), the open source version of [Ansible Tower](https://www.ansible.com/tower).

## Requirements

This role will also install (Git, Ansible, Docker) on the endpoint if they
aren't already installed. 

## Role Variables

Available variables are listed below, along with default values (see `defaults/main.yml`):

    awx_repo: https://github.com/ansible/awx.git
    awx_repo_dir: "~/awx"
    awx_version: devel
    awx_keep_updated: true

Variables to control what version of AWX is checked out and installed.

    awx_run_install_playbook: true

By default, this role will run the installation playbook included with AWX (which builds a set of containers and runs them). You can disable the playbook run by setting this variable to `no`.
