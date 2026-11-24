# proxmox_openid

Configures Proxmox VE sign-in through Entra ID. The role:

- creates or updates the OpenID realm (`entra`)
- reads the token's `groups` claim
- maps chosen Entra groups to PVE groups with ACLs
- grants named users a role on `/`

It runs from `playbooks/proxmox.yml`, which loads the client ID and the
administrators for the environment from `group_vars/proxmox/<runtime_env>.yml`.
The group mapping is shared between environments and lives in
`group_vars/proxmox/common.yml`.

## Who gets in, and with what

Access is controlled in two places.

| Layer | Controls | Managed by |
|---|---|---|
| Entra enterprise app | who can get a token at all | Entra, by hand (below) |
| Proxmox ACLs | what a signed-in user may do | this role |

With the current settings:

- **Users listed in `proxmox_openid_admins`** get `Administrator` on `/`.
- **Other members of `PU:LIB:devops:admins`** get `PVEAuditor` (read-only) on
  `/` through the PVE group `08b5fed6-19ce-4a1b-ba57-9c445e408a70-entra`.
- **Everyone else in the tenant** is refused by Entra (`AADSTS50105`).

A user's own ACL overrides their group's ACL at the same path, so an
administrator who is also in the group keeps `Administrator`.

The role only adds what it is told to. It never removes a group, a user or an
ACL that is not listed.

## PKCE and the client secret

Both app registrations are public clients: their redirect URIs are on the
"Mobile and desktop applications" platform, "Allow public client flows" is on,
and they have no client secret. Proxmox always uses PKCE (S256), so the PKCE
verifier is the only thing that lets Proxmox redeem the authorization code.

The role removes any `client-key` from the realm
(`proxmox_openid_remove_client_key`). Entra rejects a public client that
presents a secret, with error `AADSTS700025`.

## Entra side (not automated)

These settings live on the app registration and enterprise application for
each environment:

| Setting | Value |
|---|---|
| Enterprise app → assignment required | `appRoleAssignmentRequired = true` |
| Enterprise app → assigned users and groups | the admins and `PU:LIB:devops:admins` |
| App registration → `groupMembershipClaims` | `ApplicationGroup` (only groups assigned to the app go into the token) |
| App registration → redirect URIs | `publicClient.redirectUris`, one per node plus the cluster name, on port 8006 |
| App registration → `isFallbackPublicClient` | `true` |
| App registration → client secrets | none |

The registrations:

| Environment | App (client) ID |
|---|---|
| sandbox | `b3662fcb-e303-4bde-8e69-d5b2c4707342` |
| staging | `76e9a6ec-85c7-4402-bd8b-5ebf78226d4f` |

To check who may sign in:

```sh
SP_ID=$(az ad sp show --id <client id> --query id -o tsv)
az ad sp show --id "$SP_ID" --query appRoleAssignmentRequired
az rest --method get \
  --url "https://graph.microsoft.com/v1.0/servicePrincipals/$SP_ID/appRoleAssignedTo" \
  --query "value[].{who:principalDisplayName, type:principalType}" -o table
```

A new Entra group needs three things:

1. Assign the group to the enterprise application. Members of nested groups
   are not covered, because Entra assignment does not follow nesting.
2. Add the group's object ID to `proxmox_openid_groups`.
3. Run the playbook.

## Administrators who have not logged in

Proxmox creates an OpenID user on first login (`autocreate`), and an ACL
cannot name a user that does not exist yet. Administrators who have never
logged in are reported and skipped. Run the playbook again after their first
login to grant them the role.

## Clusters

The realm, groups and ACLs live in `/etc/pve`, which a cluster shares between
its nodes. The role still runs on every node so that nodes outside a cluster
are configured too. Every step reads the current state before writing, so
each later node in a cluster finds nothing to change.
