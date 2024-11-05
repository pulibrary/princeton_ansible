# Ansible Role: sssd_ad

This Ansible role configures an Ubuntu Jammy (22.04) machine to authenticate against an Active Directory domain using SSSD (System Security Services Daemon).

## Requirements

- Ansible 2.9 or higher
- An Ubuntu Jammy (22.04) target machine
- Access to an Active Directory domain controller
- An AD user with permissions to join machines to the domain

## Role Variables

| Variable | Description |
|---|---|
| `ad_domain` | The name of your Active Directory domain (e.g., example.com) |
| `ad_domain_controller` | The hostname or IP address of your domain controller |
| `ad_admin_user` | An Active Directory user with permissions to join machines to the domain |
| `ad_test_user` | A test user in your Active Directory domain |

## Dependencies

None

## Example Playbook

```yaml
- hosts: your_ubuntu_servers
  roles:
    - sssd_ad
