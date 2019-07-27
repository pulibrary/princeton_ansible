# Capistrano

Prepares a directory for deploy via capistrano

## Requirements

None.

## Role Variables

Available variables are listed below, along with default values (see `defaults/main.yml`):


## Dependencies

These are listed in `meta/main.yml`

## Example Playbook

    - hosts: server
      roles:
        - { role: pulibrary.capistrano }
