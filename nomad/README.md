# Nomad Infrastructure

Nomad is our container orchestration infrastructure. This directory contains services that are part of global infrastructure, but can be deployed and used as single containers.

## Environments

We have two Nomad environments available:

- **Production** (`production`) - Live production services
- **Sandbox** (`sandbox`) - Development and experimental environment

## Secrets & Deployment

The playbooks for individual projects controls deploying and provisioning secrets for these applications. For an example, see [../playbooks/nomad_redis.yml].

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
