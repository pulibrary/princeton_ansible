# Solr

A three node SolrCloud cluster running on Nomad, coordinated by the Zookeeper
job in `nomad/zookeeper`.

## Deploying

Zookeeper must be running first, and dynamic host volumes must exist before
this job can be scheduled. Volumes are configured in
`group_vars/nomad_solr/[env].yml`, and the count there must match `solr_count`
in the HCL file. Because Docker runs with `userns-remap`, the volume is owned
by the in-container user id plus the 1000000 remap offset.

1. Deploy Zookeeper (see `nomad/zookeeper/README.md`)
2. Provision the volumes:
   `ansible-playbook playbooks/nomad_solr.yml` (defaults to sandbox)
3. Run the job: `cd nomad && ./bin/deploy solr sandbox`

## How It Finds Zookeeper

A prestart task waits until the Zookeeper service is registered in Consul, then
the server task renders `ZK_HOST` with every Zookeeper address, so Solr can
keep running if a single Zookeeper node is unavailable.

## Index Storage

Each allocation mounts a sticky host volume at `/var/solr/data`, so a
rescheduled allocation keeps its cores. Collections still need enough replicas
to survive a node being rebuilt.

## Wiping the Cluster

1. Stop the job
1. `ssh deploy@nomad-host-sandbox1.lib.princeton.edu`
1. `nomad volume status -type host | grep solr-sandbox`
1. For each volume: `nomad volume delete -type host <volume-id>`
1. Run the playbook (to recreate volumes)
1. Start the job, then recreate collections and reindex
