# Figgy Infrastructure

[Figgy](https://pulibrary.github.io/dls-handbook/applications.html#figgy) has a number of system dependencies. Before we migrate Figgy in its entirety to Nomad, this deploys those dependencies in Nomad and makes them available to our VM apps.

## Deployment

`BRANCH=main ansible-playbook playbooks/nomad_figgy_infrastructure.yml -e runtime_env=[staging/production]`
`BRANCH=main bin/deploy figgy-infrastructure [staging/production]`

### RabbitMQ

This deploys a cluster of three RabbitMQ nodes that replicates all data and fails over, to allow for any single node to be deleted.

The admin interfaces are available here:

**Staging**: https://figgy-rabbitmq-staging.lib.princeton.edu
**Production**: https://figgy-rabbitmq-production.lib.princeton.edu
