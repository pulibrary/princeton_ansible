## Nomad Infrastructure

Nomad is our container orchestration infrastructure. This directory contains services that are part of global infrastructure, but can be deployed and used as single containers.

## Secrets

Secrets for Nomad projects are handled by provisioning the nomad cluster via `ansible-playbook playbooks/nomad.yml --tags [projectname]`

## Deployment

Starting in `princeton_ansible`

1. `cd nomad`
1. `BRANCH=<branchname> ./bin/deploy <app> <env>`

`<app>` above should be the same name as one of the directories in `nomad/` and `<env>` should be the same name as one of the files in `nomad/<app>/deploy/`

## Logging into Nomad

`./bin/login`

You can see the running services in "Jobs"
