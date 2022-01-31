# 1. Maintaining role dependencies

Date: 2022-??-??

## Status

Under Discussion

## Context

We currently list role dependencies in `meta/main.yml`. This means all role dependencies are listed in a single place, and both production playbooks and Molecule tests can use that file. However, Molecule does not deduplicate role dependencies, so a role like `common`, which is a dependency for many roles in our repo, can end up running a dozen times in a single test run for a single role. This makes our test infrastructure inefficient.

If we remove role dependencies from `meta/main.yml`, we must add them to both production playbooks and `converge.yml` test playbooks. This would create a more efficient CI system and more explicit playbooks, which can be easier to learn/understand. However, it would also mean listing role dependencies in two places, leaving us vulnerable to drift and increasing our maintenance burden.

## Decision

TBD

## Consequences

Depends on Decision
