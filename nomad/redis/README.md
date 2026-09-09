# Redis

This is a highly available Redis cluster using Redis + Sentinels. It's intended for use with applications that require Sidekiq.

We use three redis servers watched by three Sentinels, which manage failover of the primary if any go down. Sidekiq does not support Redis Cluster, so this is the only HA setup we can support.

## Reasoning

A Redis cluster is moderately complex. Its main benefit is this way we don't need to worry about persistent storage on a single node, allowing us to rebuild any Nomad machine without significant downtime.

## How Failover Works

All three nodes have the same data at any given time, and one node is a primary. If the primary goes down then the remaining sentinels vote for a new primary and promote it. This process takes between 10-60 seconds, during which time applications will be unable to access the cluster. Switchover at the applications will be automatic, so long as they're pointed at all three sentinels.

## Application Configuration

See https://github.com/pulibrary/figgy/pull/7358/changes for an example of attaching an application to the cluster. Each application should have a different database.

## Copying Data to the Cluster

If you're migrating to the cluster you can migrate the data by bringing down all workers, ssh'ing to any nomad box (for example `nomad-client-staging3.lib.princeton.edu`, and running a command like this:

`sudo docker run --rm --network host --userns host riotx/riotx replicate redis://figgy-web-staging1.princeton.edu:6379/0 redis://<primary-ip>:6379/0 --target-pass <passhere>`

You can get the current primary IP by running `ssh deploy@nomad-host-prod1.lib.princeton.edu nomad exec -task sentinel -job redis-staging redis-cli -p 26379 SENTINEL get-master-addr-by-name redis-staging`

You can get the password in `group_vars/all/vault.yml`.

## Warnings

1. Do not increase the count of replicas and then decrease them later. Sentinel increases the required number of replicas for "quorum" if this happens, making failover impossible. For instance, if we go from 3 to 4, then back down to 3, quorum raises from "2", to "3", and then if any sentinel goes down they're unable to vote for a leader.

## Helpful Links

[Redis Sentinel Documentation](https://redis.io/docs/latest/operate/oss_and_stack/management/sentinel/)
[HA Docker Compose Tutorial](https://oneuptime.com/blog/post/2026-03-31-redis-sentinel-docker-compose/view)
