---
name: Decommission infrastructure
about: Checklist for decommissioning infrastructure
title: ''
labels: ''
assignees: ''

---
### Basic details

Who is the service owner?
- [ ] Owner:

How do we know we need to decommission this infrastructure?
- [ ] Signoff (screenshot or text):

Is this virtual or physical infrastructure?
- [ ] virtual 
- [ ] physical

Are we decommissioning a site/URL also?
- [ ] no
- [ ] no, but site traffic will be redirected
- [ ] yes, site will be removed entirely

We also have [documentation on our decommissioning process](https://gitlab.lib.princeton.edu/ops/team-handbook/-/blob/main/services/decommissioning.md) in the operations team's handbook.

### Decommissioning checklist

Step 1: Network disconnection
- [ ] Disconnect the machine(s) from the network for 30 days.
  - [ ] Post a comment with the date of disconnection.

Step 2: Remove (for physical machines) or archive and delete (for virtual machines)
- [ ] For physical machines:
  - [ ] After 30 days off the network, physically remove from rack. 
    - [ ] Post a comment with the date removed from rack.
  - [ ] After 6 months out of the rack, low-level format the disk or pull out all disk drives and send to Surplus for shredding. Record and send hardware to Surplus.
    - [ ] Post a comment with the date this work was done.
- [ ] For virtual servers:
  - [ ] After 30 days off the network, copy VM files to archival disk.
  - [ ] Delete from virtual environment - this will remove a VM from VEEAM as well. 
  - [ ] Post a comment with the date the files were archived and the VM was deleted.

Step 3: Clean up related records and infrastructure
- [ ] Remove network records (host database entries)
- [ ] Remove library firewall rules 
- [ ] Remove border firewall rules if present
- [ ] Remove from princeton_ansible inventory if present
- [ ] If we are redirecting a site, update nginxplus config files in princeton_ansible
- [ ] If we are decommissioning a site, remove nginxplus config files in princeton_ansible
- [ ] If we are decommissioning a site, remove group variables from princeton_ansible
- [ ] If we are decommissioning a site, remove alias from the load balancers' network record
- [ ] If we removed nginxplus config files, or are decommissioning a machine that had SSL set up, revoke the TLS certificates
- [ ] Remove from CheckMK
- [ ] Remove from Datadog if present
- [ ] Remove from Cohesity if present
- [ ] Remove from BigFix if present
- [ ] Remove computer account from domain if joined
- [ ] Remove from inventory spreadsheet

### Implementation notes, if any
