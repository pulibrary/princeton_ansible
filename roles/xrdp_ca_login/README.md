# xrdp_ca_login

Remote desktop sign-in for hosts whose identity comes from the Library SSH
certificate authority ([`step_ca`](../step_ca) and
[`ssh_ca_trust`](../ssh_ca_trust)) rather than from a shared local account or a
cloud directory attached to PAM.

This is a policy overlay. [`roles/xrdp`](../xrdp) builds the desktop and
`ssh_ca_trust` creates the accounts; this role decides how people get to it.

## The problem it solves

A remote desktop wants a per-person credential, and an RDP login window cannot
carry one. xrdp answers every PAM password prompt with the single string typed
into its box and discards informational text, so nothing interactive fits: no
device-code MFA, no one-time code, and no certificate. Whatever is typed there is
a single factor by construction.

Attaching a cloud directory to PAM does not change that. It changes *which*
password is a single factor.

So this role stops trying to make the login window strong and takes it off the
network instead:

1. **Getting to the login window needs a certificate.** The RDP listener is bound
   to `127.0.0.1`, so the only route in is a port forwarded inside an SSH
   session, and sshd on these hosts accepts short-lived certificates rather than
   passwords. A certificate is only issued after an Entra ID sign-in, with
   whatever MFA Conditional Access requires, and expires within hours.

2. **The login window then takes an ordinary local password.** It is not a way in
   by itself, and it is never shared: each person sets their own with a
   self-service command, over a session they could only open with a certificate.

The result is that desktop access is gated on a current Entra ID sign-in, and
revoking someone's Entra access revokes their desktop access, without any
credential an administrator knows.

## What it does

- **Verifies the RDP port is listening on loopback only**, reading the live
  socket rather than trusting a config setting, so a package update or a setting
  that looks right and does nothing cannot quietly put the login window back on
  the network
- Removes an `address` key from `xrdp.ini` if one is present, because xrdp
  accepts it in silence and ignores it
- Permits SSH port forwarding, so a hardened base image cannot cut off the tunnel
- Adds the certificate-backed accounts to the groups a desktop session needs
  (`audio`, `video`, `plugdev`, `netdev`) plus a `rdpusers` group
- Installs a self-service command for setting one's own desktop password, with a
  sudo rule scoped to that one command
- Ensures `systemd-logind` is running, without which a session opens and closes
  again immediately
- Refuses to run, with a specific message, if the desktop or the CA trust is
  missing, since both otherwise present as a failed login

## Binding the listener

The bind address is set through [`roles/xrdp`](../xrdp), which owns the port line
in `xrdp.ini`:

```yaml
xrdp_listen_address: 127.0.0.1
```

This role deliberately does **not** write that line. If both roles wrote it they
would overwrite each other on every run and restart xrdp each time, killing live
desktop sessions. This role checks the outcome instead.

Note that xrdp has no `address` setting: the bind address is part of the port
value, as `port=tcp://127.0.0.1:3389`. An `address=127.0.0.1` key is accepted
without complaint and does nothing, which is a trap worth knowing about because
the file then reads as though it were bound to loopback while the daemon listens
on every interface. That is precisely what the socket check catches.

## Variables

```yaml
# Defaults to the accounts in ssh_ca_users, so desktop access and certificate
# access are one list rather than two that drift.
xrdp_ca_login_users: "{{ ssh_ca_users | map(attribute='name') | list }}"

xrdp_ca_login_group: rdpusers
xrdp_ca_login_session_groups: [audio, video, plugdev, netdev]

# The bind address itself is roles/xrdp's xrdp_listen_address; this only decides
# whether to fail the run when the resulting socket is reachable off-host.
xrdp_ca_login_assert_not_exposed: true

xrdp_ca_login_password_helper: true
xrdp_ca_login_helper_path: /usr/local/sbin/set-desktop-password

xrdp_ca_login_show_instructions: true
xrdp_ca_login_ca_url: https://step-ca.lib.princeton.edu:8443
```

## The firewall

No RDP rule is needed, and adding one would misdescribe how the host is reached.
`roles/xrdp` depends on the `firewall` role with `firewall_allow_rdp: true`; an
empty source list turns that request into no rules:

```yaml
firewall_rdp_cidrs: []
```

This matters more than it first appears: `firewall_trusted_cidrs` opens **every**
port to the library private subnet, so binding to loopback rather than any
firewall rule is what actually keeps RDP off the network.

Exposing the port instead means setting `xrdp_listen_address: ""` in
`roles/xrdp`, opening the firewall to match, and accepting that the desktop
password becomes a single factor reachable from any permitted network. Prefer the
tunnel.

## What a person does

**Every command below runs on the person's own computer, not on the server.**
This is the step people get wrong: running the tunnel command on the server
reports `bind [127.0.0.1]:3389: Address already in use`, because the desktop is
already listening there.

```sh
# once per computer; fingerprint is in group_vars/step_ca/vault.yml
step ca bootstrap --ca-url https://step-ca.lib.princeton.edu:8443 \
  --fingerprint <fingerprint>

# once per person: set the desktop password (a local one, not Entra ID)
step ssh login netid@princeton.edu
ssh netid@desktop.princeton.edu
sudo /usr/local/sbin/set-desktop-password
exit

# each time the desktop is needed; certificates are short lived
step ssh login netid@princeton.edu
ssh -L 3389:localhost:3389 netid@desktop.princeton.edu
```

Leave that SSH session open and point the RDP client at **`localhost:3389`**, not
at the server's name. A client aimed at the server cannot connect, because
nothing outside the host answers on the desktop port. That is the point.

The role prints these steps at the end of a run, with the host's real name filled
in, because none of it is discoverable from the host itself.

## Troubleshooting

| Symptom | Cause |
| --- | --- |
| RDP client cannot connect (`0x204` on macOS) | Client aimed at the server's name instead of `localhost`, or the SSH session holding the tunnel has ended |
| `bind [127.0.0.1]:3389: Address already in use` | The `ssh -L` command is being run on the server instead of on your own computer |
| Password prompt when you expected the certificate to work | Your Entra identity maps to no local account; see the guard in `playbooks/bitcurator_sandbox.yml` |
| `Too many authentication failures` | Your SSH agent is offering more keys than sshd will accept before it gives up |
| Sign-in refused at the login window | Desktop password wrong or never set; rerun the self-service command |
| Session opens then closes immediately | Session startup, not authentication: see `/var/log/xrdp-sesman.log` |

`Too many authentication failures` is worth a `~/.ssh/config` entry. `step ssh
login` puts the certificate in your agent, but sshd counts every other key your
agent offers first and disconnects before reaching it:

```ssh-config
Host *.princeton.edu
    IdentitiesOnly yes
    IdentityAgent SSH_AUTH_SOCK
```

## Example play

Order matters and is deliberately not enforced by role metadata, so that it stays
visible in the playbook:

```yaml
- hosts: bitcurator_desktops
  become: true
  vars:
    # Owned by roles/xrdp: renders port=tcp://127.0.0.1:3389
    xrdp_listen_address: 127.0.0.1
  roles:
    # Trusts the CA and creates one local account per person.
    - role: ssh_ca_trust
    # Builds the no-sleep XFCE desktop and binds the listener.
    - role: xrdp
    # Gives those accounts a session, and verifies the binding held.
    - role: xrdp_ca_login
```

`playbooks/bitcurator_sandbox.yml` is the worked example.

## Testing

```sh
molecule test
```

The scenario installs the **real** xrdp so the socket check runs against a real
listening daemon, starts it on every interface, and confirms the role both
notices that and fixes it. It also re-exposes the port afterwards and asserts the
check fails, so a check that could never fail cannot pass for that reason.

The first version of this scenario faked xrdp with a script that never listened
on 3389. Everything passed while the check was vacuous, and a real host went out
with its login window on every interface.

## Notes

- The self-service sudo rule is scoped to a single command on purpose. On a host
  where the desktop users are also administrators (for instance one that grants
  an operator group `NOPASSWD: ALL`) that scoping is redundant, but the role does
  not assume administrators, and the narrow rule is what makes it safe to apply
  where desktop users are ordinary users.
- Desktop passwords are local, so a rebuild loses them and each person sets
  theirs again. Nothing else is lost: identity lives in Entra ID and the CA.
- `himmelblau_entra_id` is the alternative approach, in use where a cloud
  directory is attached to PAM directly and people sign in at the login window
  with a device-bound PIN. The two are independent; a host uses one or the other.
