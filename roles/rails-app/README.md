# Rails App

Installs a generic rails app

## Requirements

None.

## Role Variables

Available variables are listed below, along with default values (see `defaults/main.yml`):

    rails_app_name: rails_app

The name of the application

    rails_app_directory: rails_app

The directory of your the application application

    rails_app_symlinks: []
    rails_app_dependencies: []
    rails_app_vars: []

A python dictionary of found in `group_vars/lae_production.yml`

    rails_app_env: staging

The rails environment

## Dependencies

None.

## Example Playbook

    - hosts: server
      roles:
        - { role: pulibrary.rails-app }
