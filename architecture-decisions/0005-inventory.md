# 1. Split inventory into per-project files

Date: 2022-08-23

## Status

Accepted

## Context

There are a lot of different ways to manage inventory in Ansible and we should have a consistent way to do it that matches our other patterns.

We want to make project-specific inventory easy to manage and find for the various development groups. We also want to make it easy to run infrastructure updates across classes of VMs (all the staging/production/qa machines, possibly all the apache/nginx/drupal machines). We want to make maintenance and management easier for inventory, with alphabetization and other helpful clues built in. Finally, we want to make it harder to run a playbook against too many / the wrong VMs by mistake by reducing our use of `hosts: all`.

## Decision

We will delete our flat hosts file and create an inventory directory. The directory will contain multiple sub-directories, including:

1. The `all_projects` directory, containing a separate file for each project. Each file must include all necessary inventory groups (for example, figgy_production, figgy_workers, figgy_web_production, and so on). The files in this directory should match the sub-directories in the `group_vars` directory.
1. The `by_environment` directory, containing a file for each environment (production, qa, staging). These files should contain only groups made up of child groups from the project-specific files.
1. Other directories that allow different methods of grouping inventory (by web server type for example - nginx or apache).

NOTE: The `all_projects` directory must be the first directory listed (in other words, alphabetically by linux/ASCII alphabetization it must come first), because Ansible loads inventory in ASCII order. You must have the child groups (from the files in `all_projects`) loaded before you can create the parent groups in `by_environment`.

## Consequences

* Make finding groups and VMs in inventory easier.
* A lot more inventory files.
* Each VM will appear in multiple groups.
* Existing groups will still work.
* We can stop using the risky `hosts: all` in our playbooks.
