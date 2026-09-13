# Zookeeper

A three node Zookeeper ensemble that provides coordination for the Solr cloud
cluster running on Nomad.

## Deploying

Dynamic host volumes must exist before this job can be scheduled. They are
configured in `group_vars/nomad_zookeeper/[env].yml`, and the count there must
match `zookeeper_count` in the HCL file. Because Docker runs with
`userns-remap`, the volume is owned by the in-container user id plus the
1000000 remap offset.

1. Provision the volumes:
   `ansible-playbook playbooks/nomad_zookeeper.yml` (defaults to sandbox)
2. Run the job: `cd nomad && ./bin/deploy zookeeper sandbox`

## How Membership Works

Each allocation registers itself in Consul with an `alloc_index` in its service
metadata. Every node uses that metadata to build its `ZOO_SERVERS` list, so the
ensemble reforms itself after any node is rescheduled. The allocation index
(plus one) is the Zookeeper node id, and node data lives on a sticky host
volume so a rescheduled allocation keeps its state.

## Wiping the Ensemble

The playbook only creates volumes that don't exist yet, it never changes an
existing one. So if the ownership was wrong, or you want to start over, the
volumes have to be deleted and recreated:

1. Stop the job
1. `ssh deploy@nomad-host-sandbox1.lib.princeton.edu`
1. `nomad volume status -type host | grep zookeeper-sandbox`
1. For each volume: `nomad volume delete -type host <volume-id>`
1. Run the playbook (to recreate volumes)
1. Start the job

Wiping Zookeeper discards all Solr cloud state (collections, configsets, and
cluster topology), so Solr must be reindexed afterwards.

## Troubleshooting

`/docker-entrypoint.sh: line 47: /data/myid: Permission denied` means the host
volume isn't writable by the container's user. Check what the directory is
actually owned by on the client that's running the allocation:

```bash
ssh pulsys@nomad-client-sandbox1.lib.princeton.edu \
  'sudo ls -lnd /container_data/zookeeper-sandbox*'
```

The owner must be the container uid plus the userns-remap offset (1001000).
If it isn't, delete and recreate the volumes as described above.
