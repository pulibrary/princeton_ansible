# CircleCI Deployer

This is a self hosted machine runner for CircleCI. We use it for deploys as part of a continuous deployment process.

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
    resource_class: pulibrary/ruby-deploy
    steps:
      - run: echo "Hi I'm on Runners!"
```

## Deployment

Make sure you push the branch that has any changes to the container, and wait for it to generate. Then specify the branch you want to deploy.

`BRANCH=[my-branch] ansible-playbook playbooks/circlei_deployer.yml`

You can track progress and status of nomad apps by looking at the Nomad UI, accessible from `./bin/login`
