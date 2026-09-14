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

The playbook only creates volumes that don't exist yet, it never changes an
existing one. So if the ownership was wrong, or you want to start over, the
volumes have to be deleted and recreated:

1. Stop the job
1. `ssh deploy@nomad-host-sandbox1.lib.princeton.edu`
1. `nomad volume status -type host | grep solr-sandbox`
1. For each volume: `nomad volume delete -type host <volume-id>`
1. Run the playbook (to recreate volumes)
1. Start the job, then recreate collections and reindex

## Troubleshooting

A "Permission denied" error writing under `/var/solr` means the host volume
isn't writable by the container's user. Check what the directory is actually
owned by on the client that's running the allocation:

```bash
ssh pulsys@nomad-client-sandbox1.lib.princeton.edu \
  'sudo ls -lnd /container_data/solr-sandbox*'
```

The owner must be the container uid plus the userns-remap offset (1008983).
If it isn't, delete and recreate the volumes as described above.
