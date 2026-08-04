# 1. Align inventory environments with infrastructure

Date: 2026-07-27

## Status

Approved

## Context

We have two infrastructure environments: staging and production.

We have four inventory environments: ci, qa, staging, and production. It's possible we could have more in future.

We want to make automation simple and straightforward and limit the number of variables we need to pass for automation.

## Decision

We will maintain our inventory to reflect the basic division between the staging infrastructure and the production infrastructure.

1. All `QA` VMs run on our `production` infrastructure.
2. The `qa` inventory group will  be a member of the `production` group.
3. All other non-production VMs, including `CI` run on our `staging` infrastructure. 
4. The `ci` inventory group and any other inventory groups we create in future will be members of the `staging` group.
5. We can create and maintain `ci` and `qa` and other top-level inventory groups under `inventory/by_environment` if we want to, so we can easily target similar VMs together.

## Consequences

* We can continue to use the `runtime_env` variable to pass a value for both the inventory group and the infrastructure environment.
* We must maintain the correct assignment of VMs in our infrastructure and our inventory.
