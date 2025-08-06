# Ruby App

Installs a generic ruby app (Hanami or Rails running on puma have been tested)

## Requirements

None.

## Using Ruby 3.x

By default, this role uses ruby 2.7. To instead use 3.x, define the following variables:

```
install_ruby_from_source: true
ruby_version_override: "ruby-3.0.3"
```

## Updating just the vars

To update the ruby app env vars in your application but nothing else, run your
playbook with --tags=site_config

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
        - { role: ruby_app }
