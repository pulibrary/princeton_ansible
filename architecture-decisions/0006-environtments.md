# 1. Align inventory environments with infrastructure

Date: 2026-07-27

## Status

Draft

## Context

We have two infrastructure environments: staging and production.

We have four inventory environments: ci, qa, staging, and production. It's possible we could have more in future.

We want to make automation simple and straightforward and limit the number of variables we need to pass for automation.

## Decision

We will maintain our inventory to reflect the basic division between the staging infrastructure and the production infrastructure.

1. All `CI` VMs run on our `staging` infrastructure. 
2. All `QA` VMs run on our `production` infrastructure.
3. We will maintain `ci` and `qa` inventory groups so we can easily target similar VMs together.
4. The `ci` inventory group will be a member of the `staging` group.
5. The `qa` inventory group will  be a member of the `production` group.

## Consequences

* We can continue to use the `runtime_env` variable to pass a value for both the inventory group and the infrastructure environment.
* We must maintain the correct assignment of VMs in our infrastructure and our inventory.
