# 1. Record architecture decisions

Date: 2022-08-12

## Status

Draft

## Context

There are a lot of different ways to manage inventory in Ansible and we should have a consistent way to do it that matches our other patterns.

We want to make project-specific inventory easy to manage and find for the various development groups. We also want to make it easy to run infrastructure updates across classes of VMs (all the staging/production/qa machines, possibly all the apache/nginx/drupal machines). We want to make maintenance and management easier for inventory, with alphabetization and other helpful clues built in. Finally, we want to make it harder to run a playbook against too many / the wrong VMs by mistake by reducing our use of `hosts: all`.

## Decision

We will delete our flat hosts file and create an inventory directory. The directory will contain a file for each project with all necessary inventory groups (for example, figgy_production, figgy_workers, figgy_web_production, and so on). It will also contain sub-directories for other methods of grouping inventory.

## Consequences

* Make finding groups and VMs in inventory easier.
* A lot more inventory files.
* Each VM will appear in multiple groups.
* Existing groups will still work.
