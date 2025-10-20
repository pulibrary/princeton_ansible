# Ruby App

Installs components needed to serve generic ruby app (Hanami or Rails running on puma have been tested)

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
For backwards compatibility any ruby_ var can also be set by rails_

Available variables are listed below, along with default values (see `defaults/main.yml`):

    ruby_app_name: ruby_app

The name of the application

    ruby_app_directory: ruby_app

The directory of your the application application

    ruby_app_symlinks: []
    ruby_app_dependencies: []
    ruby_app_vars: []

A python dictionary of found in `group_vars/lae_production.yml`

    rails_app_env: staging

The rails environment

## Dependencies

None.

## Example Playbook

    - hosts: server
      roles:
        - { role: ruby_app }
