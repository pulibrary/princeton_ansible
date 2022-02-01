# 1. Maintaining role dependencies

Date: 2022-??-??

## Status

Under Discussion

## Context

We currently list role dependencies in `meta/main.yml`. This means all role dependencies are listed in a single place, and both production playbooks and Molecule tests can use that file. However, Molecule does not deduplicate role dependencies, so a role like `common`, which is a dependency for many roles in our repo, can end up running a dozen times in a single test run for a single role. This duplication makes our test infrastructure inefficient.

## Decision

TBD

## Consequences

If we remove role dependencies from `meta/main.yml`, we must add them to both production playbooks and `converge.yml` test playbooks. This would create a more efficient CI system and more explicit playbooks, which can be easier to learn/understand. However, it would also mean listing role dependencies in two places, leaving us vulnerable to drift and increasing our maintenance burden.

## Logistics

Changing the way we maintain role dependencies will require some refactoring. For each role dependency we remove from the `meta/main.yml` file of Role A, we must:

- ensure the README for Role A lists the dependency
- add the dependency to the `molecule/default/converge.yml` file for Role A, so it runs in tests
- add the dependency to every playbook that runs Role A
- until all roles are converted, add the dependency to `meta/main.yml` for any other role that lists Role A as a dependency, and to any playbooks that run those roles

If we decide to maintain role dependencies in playbooks (production and test), we should update this ADR when the transition is complete, to document requirements for maintaining role dependencies going forward.
