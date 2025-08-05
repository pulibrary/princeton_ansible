# Nomad Infrastructure

Nomad is our container orchestration infrastructure. This directory contains services that are part of global infrastructure, but can be deployed and used as single containers.

## Environments

We have three Nomad environments available:

- **Production** (`production`) - Live production services
- **Sandbox** (`sandbox`) - Development and experimental environment

## Secrets

Secrets for Nomad projects are handled by provisioning the nomad cluster via:

```bash
# For production
ansible-playbook playbooks/nomad.yml -e runtime_env=production --tags [projectname]

# For sandbox
ansible-playbook playbooks/nomad.yml -e runtime_env=sandbox --limit nomad_sandbox --tags [projectname]
```

## Deployment

Starting in `princeton_ansible`:

1. `cd nomad`
2. `BRANCH=<branchname> ./bin/deploy <app> <env>`

Where:
- `<app>` should be the same name as one of the directories in `nomad/`
- `<env>` should be one of: `production` or `sandbox`
- The environment should match one of the files in `nomad/<app>/deploy/`

### Examples

```bash
# Deploy to production (default branch: main)
./bin/deploy myapp production

# Deploy specific branch to sandbox
BRANCH=feature-branch ./bin/deploy myapp sandbox

# Deploy to sandbox for testing
./bin/deploy myapp sandbox

# Deploy from different repository
REPO=my-other-repo ./bin/deploy myapp sandbox
```

## Logging into Nomad

Access the Nomad UI for different environments:

```bash
# Production
./bin/login

# Sandbox (default)
./bin/login sandbox
```

You can see the running services in "Jobs" section of the Nomad UI.

## Environment URLs

- **Production**: https://nomad.lib.princeton.edu
- **Sandbox**: https://nomad-sandbox.lib.princeton.edu

## Prerequisites

- VPN connection to Princeton network
- SSH access to the appropriate nomad hosts
- Proper permissions on the target environment

## Troubleshooting

If you encounter connection issues:

1. Ensure you're connected to the Princeton VPN
2. Verify SSH access to the nomad hosts:
   - Production: `nomad-host-prod1.lib.princeton.edu`
   - Sandbox: `nomad-host-sandbox1.lib.princeton.edu`
3. Check that the deploy user exists and has proper permissions on the target environment
