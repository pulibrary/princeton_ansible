# 1. Record architecture decisions

Date: 2020-01-16

## Status

Accepted

## Context

There are a lot of different ways to set variables in Ansible and we should have
a consistent way to do it in all playbooks for each group.

We want to make sure that there's a smaller vault.yml file per group, instead of
a gigantic vault.yml file for everything. This is because one huge vault.yml
file causes merge conflicts in multiple Github Pull Requests.

## Decision

Unique group variables will be placed in `/group_vars/<groupname>`
Encrypted group variables will be placed in `/group_vars/<groupname>/vault.yml`

Shared group variables will be placed in `/group_vars/all/`

## Consequences

* Reduce conflicts in merging pull requests.
* A lot more vault files.
* You have to explicitly add the variable files in your playbook.
  E.g:
  ```
  vars_files:
    - ../group_vars/libwww/libwww-prod.yml
    - ../group_vars/libwww/vault.yml
  ```
* Variables in the `/group_vars/all` directory will still be used.
