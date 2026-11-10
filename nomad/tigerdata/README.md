# TigerData CI Deployer

This is a self hosted machine runner for CircleCI, dedicated to TigerData.
We use it for deploys as part of a continuous deployment process, and for
functional tests that need Mediaflux, which is only reachable from inside
the PUL firewall.

It is separate from the shared `circleci_deployer` runner so that TigerData
jobs do not queue behind unrelated application deploys, and because this
image additionally ships Chrome and a matching ChromeDriver for Capybara
feature specs.

## How to Use in CircleCI

```ruby
version: 2.1
workflows:
  testing:
    jobs:
      - runner-test
jobs:
  runner-test:
    machine: true
    resource_class: pulibrary/tigerdata-deploy
    steps:
      - run: echo "Hi I'm on Runners!"
```

## Deployment

Make sure you push the branch that has any changes to the container, and wait for it to generate. Then specify the branch you want to deploy.

```bash
BRANCH=[my-branch] ansible-playbook playbooks/tigerdata_ci_deployer.yml
```

You can track progress and status of nomad apps by looking at the Nomad UI,
accessible from `./bin/login`.
