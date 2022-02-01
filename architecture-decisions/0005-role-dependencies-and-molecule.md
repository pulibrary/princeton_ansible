# 1. Maintaining role dependencies

Date: 2022-02-04

## Status

Accepted

## Context

Previously, we listed role dependencies in `meta/main.yml`. This meant all role dependencies were listed in a single place, and both production playbooks and Molecule tests used that file. However, Molecule did not deduplicate role dependencies, so a role like `common`, which is a dependency for many roles in our repo, could run a dozen times in a single test run for a single role. This duplication made our test infrastructure inefficient.

## Decision

Remove role dependencies from `meta/main.yml` and track them in playbooks instead.

## Consequences

When we remove role dependencies from `meta/main.yml`, we must add them to both production playbooks and `converge.yml` test playbooks. This creates a more efficient CI system and more explicit playbooks, which can be easier to learn/understand. However, it also means listing role dependencies in two places, leaving us vulnerable to drift and increasing our maintenance burden.

See [issue #2685](https://github.com/pulibrary/princeton_ansible/issues/2685) for further details.
