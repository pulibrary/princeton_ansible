PUL Nomad
=========

Configures a Nomad/Consul cluster for deployment of PUL's container applications. Sets up Nomad & Consul Clients and Servers.

# Design Considerations

1. After initial setup, this role should be runnable on a single node.
1. Prefer explicit configuration over excessive variables and defaults.
1. Prefer simplicity over edge cases.
1. Readability and understanding is the #1 goal.
1. Use idempotent modules when possible to reduce complex check/act loops.
1. Separate "servers" from "clients" when possible, as has been our pattern.

# Running a local cluster and testing

1. `cd` to this role's directory.
1. `molecule reset`
1. `molecule converge`
1. Visit `http://localhost:4646` for Nomad.
1. Visit `http://localhost:8500` for Consul.
1. `molecule verify` to run tests.

# Cluster Install Workflow (what this role does)

1. Install & Start Consul Servers (necessary for the rest of the infrastructure to talk to)
1. Install DNSMasq
1. Install & Start Consul Clients
1. Install Consul ACLs & Tokens
1. Install & Start Nomad Servers
1. Bootstrap Nomad ACLs
1. Install & Start Nomad Clients
1. Configure Applications

# Architecture Documentation

## Variable Documentation

Variables have defaults in [`defaults/main.yml`](defaults/main.yml) and may be defined in [`group_vars`](../../group_vars) within `nomad_cluster.yml`, `nomad_servers.yml`, `nomad_clients.yml`, `nomad_clients_<env>.yml`, or for specific hosts in [`host_vars`](../../host_vars/) to enable host volumes

* `nomad_server_group` - the ansible group that contains all the servers for a given cluster. We need to know these because Consul uses their IPs to build a cluster.
* `pul_nomad_role` - Either `client` or `server`.
* `consul_version` - version of consul to install - [releases](https://github.com/hashicorp/consul/releases)
* `nomad_version` - version of nomad to install - [releases](https://github.com/hashicorp/nomad/releases)
* `nomad_podman_version` - version of nomad's podman plugin to install - [releases](https://github.com/hashicorp/nomad-driver-podman/releases)
* `nomad_node_pool` - pool to assign to a client. Right now we have `staging` and `production`, where production is the servers that are on our prod VM infrastructure.
* `nomad_host_volumes` - map of host volumes to create and make available to containers. Example: 
    ```
    nomad_host_volumes:
      - name: loki
        path: '/container_data/loki'
        read_only: false
    ```
* `nomad_meta` - map of meta attributes to assign to the Nomad host. Example:
    ```
    nomad_meta:
      node_type: 'worker'
    ```
* `consul_gossip_encryption_key` - Gossip encryption key for consul/nomad servers.
* `consul_acl_management_token` Consul management token. See [Permissions & ACLs](#permissions--acls)
* `pul_nomad_management_token` Nomad management token. See [Permissions & ACLs](#permissions--acls)

## Consul

Consul is a service registration system with a DNS API.

What this means is that you can register services in it, like
`128.4.1.2 on port 8216 is a postgres database`, and then other services can
configure their DB host to `postgres-database.service.consul` and consul will
route it to `128.4.1.2:8216`.

Multiple services can be registered to the same name and Consul will load
balance them, and consul can health check the services to make sure it doesn't
route anything to services that are broken.

### Server Types

Consul has "servers" and "clients."

We run 3 servers and a client on every Nomad client.

The servers create a mesh for high availability. We run a Consul server on every
Nomad server for convenience. These are named `nomad-host-*.lib.princeton.edu`.

Clients run local DNS servers that forward their requests to the servers. We run
one on every Nomad client. These are named `nomad-client-*.lib.princeton.edu`

### Configuration

Every Consul installation (clients and servers) have a primary configuration at `/etc/consul.d/consul.hcl` which we create from [`templates/consul/consul.hcl.j2`](templates/consul/consul.hcl.j2). You can find all the possible configuration values in the [documentation](https://developer.hashicorp.com/consul/docs/reference/agent/configuration-file) (you may need to navigate the table of contents on the left to find more options.)

Every Consul server has an extra configuration at `/etc/consul.d/server.hcl.j2` which we create from [`templates/consul/server.hcl.j2`](templates/consul/server.hcl.j2).

The "gossip encryption key" is a key used to encrypt communication between Consul servers. We use the same key for both Consul & Nomad.

### DNSMasq

Consul runs a DNS interface on port 8600, but most servers look for DNS on port 53.
We install DNSMasq as a DNS proxy which will both cache DNS requests and forward
any requests for `*.consul` to `127.0.0.1:8600`.

We don't run Consul on port 53 because while it can forward DNS requests to
other Princeton's DNS it  overrides their TTL to be 0, which will quickly overwhelm
Princeton's DNS server.

#### Configuration

DNSMasq's main config file is at `/etc/dnsmasq.conf` which we create from [`files/dnsmasq/dnsmasq.conf`](files/dnsmasq/dnsmasq.conf). The main thing we do there is comment out `bind-interfaces` [#5485](https://github.com/pulibrary/princeton_ansible/pull/5485).

There's a second config file at `/etc/dnsmasq.d/dnsmasq-10-consul` which we create from [`templates/dnsmasq/dnsmasq-10-consul.j2`](templates/dnsmasq/dnsmasq-10-consul.j2). It configures Princeton's DNS servers and the fallback to Consul for `.consul` DNS requests.

#### Debugging

To test if DNSMasq is working on a client, run `dig @127.0.0.1 -p 8600 consul.service.consul ANY` and compare it to the results of `dig consul.service.consul ANY`. If they have the same answers, DNSMasq is working.

If you need to flush the DNS Cache because IPs have changed, you can restart DNSMasq with `sudo service dnsmasq restart`

## Nomad

Nomad is a container orchestrator.

What this means is you can write job files, tell Nomad to deploy them, and Nomad
will automatically find a server in the cluster that can run them. If that
server goes down it will launch the container on a different server.

We install Podman on our Nomad clients so it can run containers without us
having to rely on Docker.

### Server Types

Nomad has "servers" and "clients."

We run 3 servers and a larger number of clients.

Servers manage orchestration, receive commands from clients and developers, and
maintain state about the cluster as a whole. These are named
`nomad-host-*.princeton.edu`

Clients run jobs. In our case, containers executed by Podman. These are named
`nomad-client-*.princeton.edu`

### Configuration

Nomad's full configuration reference can be found in their [documentation](https://developer.hashicorp.com/nomad/docs/configuration). You may have to use the table of contents to see details of all the sections.

Every Nomad Client & Server gets `/etc/nomad.d/base.hcl` created from [`templates/nomad/base.hcl.j2`](templates/nomad/base.hcl.j2).

Every Server gets `/etc/nomad.d/server.hcl` created from [`templates/nomad/server.hcl.j2`](templates/nomad/server.hcl.j2).

Every Client gets `/etc/nomad.d/client.hcl` created from [`templates/nomad/client.hcl.j2`](templates/nomad/client.hcl.j2)

The "gossip encryption key" is a key used to encrypt communication between Nomad servers. We use the same key for both Consul & Nomad.

### Consul Interaction

Nomad uses Consul for clustering (the Nomad servers find each other by querying
Consul) and service discovery (when you launch a job in Nomad it can register a
service in Consul that we can point to from our load balancers.)

### Host Volumes

Host volumes are a way for containers to save data to the underlying client. It's a folder on the client which the container maps - if a job requires a certain host volume it will only ever get scheduled on a node which has that volume.

These are necessary for any containers that has data which should survive a reboot.

Nomad has a useful [tutorial](https://developer.hashicorp.com/nomad/tutorials/stateful-workloads/stateful-workloads-host-volumes) about how they work.

More recent versions of Nomad have "dynamic host volumes" which would allow us to create these on the fly, not in Ansible, but we're not upgraded enough for that. Nomad has a [tutorial](https://developer.hashicorp.com/nomad/tutorials/stateful-workloads/stateful-workloads-dynamic-host-volumes) for those.

### Application Configurations

Containers deployed to the Nomad architecture may still need external systems provisioned and variables persisted to Nomad. For example an application may need a postgres database set up on our cluster, secrets installed into Nomad (which are currently in Ansible Vault), or other configuration done.

Those things happen in [`tasks/application_configurations.yml`](tasks/application_configurations.yml).

This pattern may change in the future. If you want to run a playbook without running these application configurations you can do: `ansible-playbook playbooks/nomad.yml --skip-tags app_config`

## Permissions & ACLs

Both [Consul](https://developer.hashicorp.com/consul/docs/secure/acl) and [Nomad](https://developer.hashicorp.com/nomad/tutorials/access-control/access-control) have ACLs (Access Control Lists) to restrict the permissions each has on the other and how developers interact with them.

This documentation hopes to make it clear how we implement ACLs in this role.

Tokens (UUID) point to Policies which point to individual rules.

### Management Tokens

When the server is first provisioned we define a "management token" (variables `pul_nomad_management_token` and `consul_acl_management_token`).
These tokens are full-access tokens that can do anything in the system. We use them in Ansible to provision more restrictive tokens, and developers can use them to navigate the system if needed.

### Consul Tokens

These are set up in `tasks/consul/acl.yml`.

Every client and server in the cluster has Consul installed. Some tokens are global (the same on every node), some are local (a unique token per node.) Each pul_nomad installation uses these consul tokens:

1. **DNS Token (global)**: Consul's [DNS service](https://developer.hashicorp.com/consul/docs/discover/dns) uses this token to get service information from the cluster. If this is wrong or unset, `dig @127.0.0.1 -p 8600 consul.service.consul ANY` will return no answers.
1. **Agent Token (local)**: Consul's agent uses this to communicate with the rest of the cluster and synchronize services. This uses a "[node identity](https://developer.hashicorp.com/consul/docs/secure/acl/role#node-identities)" token, which has a default policy.
1. **Nomad Server Token (global)**: Allows Nomad's servers to mesh, manage ACLs, and update Consul services. Every "host" node has this configured. Defined in [nomad/configure_server.yml](tasks/nomad/configure_server.yml)
1. **Nomad Client Token (global)**: Allows Nomad's clients to update services as they're deployed. Every "client" node has this configured. Defined in [nomad/configure_client.yml](tasks/nomad/configure_client.yml)

### Nomad Tokens

We don't currently have any special nomad tokens, just the management token. We create that token when we [bootstrap](https://developer.hashicorp.com/nomad/tutorials/access-control/access-control-bootstrap) Nomad's ACL system in [nomad/server.yml](tasks/nomad/server.yml)

# Generating Variables

Some variables need to be generated and stored in the vault. To generate new
ones for consul (`consul_gossip_encryption_key`) you can run:

`docker run --rm hashicorp/consul keygen`

# Common Tasks

## Upgrading Nomad or Consul

Nomad and Consul are built to be largely backwards compatible. Nomad has good [documentation](https://developer.hashicorp.com/nomad/docs/upgrade#upgrade-process), but the process is effectively:

1. Change `nomad_version`
1. Provision one nomad host with `--limit=<nomad_host_here>`
1. Test to make sure it's in the cluster by checking the Nomad UI ([documentation](../../nomad/README.md)).
1. Do the rest of them.

The same process is true for Consul or the Podman plugin. We don't have a staging cluster to try this out in yet.
