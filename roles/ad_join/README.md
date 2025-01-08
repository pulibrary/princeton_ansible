# ad_join

This Ansible role configures a Rocky Linux 9 or Ubuntu system to join an Active Directory domain. It installs necessary packages, configures `sssd`, `krb5`, and PAM, and joins the system to the specified domain.

## Description

This role performs the following actions:

1.  Installs required packages: `realmd`, `sssd`, `oddjob`, `oddjob-mkhomedir`, `samba-common-tools`, `adcli`, `krb5-workstation`, and `openldap-clients`, `authselect-compat`.
2.  Creates a custom `authselect` profile for PAM configuration with `sssd` preferred for authentication.
3.  Copies and extracts a pre-configured custom PAM configuration to ensure proper authentication order.
4.  Templates and deploys the `sssd.conf` and `krb5.conf` configuration files.
5.  Discovers the AD realm.
6.  Joins the system to the AD domain using `realm join`.
7.  Enables and starts the `sssd` and `oddjobd` services.
8.  Configures the `sssd.conf` file to not use StartTLS, not to require a certificate, disables the Global Catalog lookups, sets the search base, and removes the `ad_access_filter`.
9.  Ensures the system time is synchronized using `chrony`.
10. Adds the necessary Kerberos Key Distribution Centers (KDCs) to the `krb5.conf` file.
11. Sets SELinux to permissive mode temporarily during configuration.
12. Ensures necessary log files and directories exist with appropriate permissions.
13. Enables Kerberos and GSSAPI authentication in the SSH server configuration.
14. Performs post-configuration checks, including testing Kerberos ticket acquisition, LDAP search connectivity, domain status, and user/group information retrieval.

## Requirements

* Ansible 2.9 or higher.
* A target system running Rocky Linux 9 (tested throughly and successfully) or Ubuntu.
* Network connectivity to the Active Directory domain.
* An Active Directory user account with sufficient privileges to join computers to the domain.
* A pre-configured custom PAM configuration packaged as `custom_pul_sssd.tar.gz` and placed in the `templates/` directory of the role.
* Access to [OIT AD Machine Registration Tool](https://tools.princeton.edu/Dept/) to register a new Active Directory name

## Role Variables

### Default Variables (`defaults/main.yml`)

*   `ad_join_ad_domain`: The Active Directory domain to join (e.g., `pu.win.princeton.edu`).
*   `ad_join_ad_realm`: The Kerberos realm, usually the uppercase version of the AD domain (e.g., `PU.WIN.PRINCETON.EDU`).
*   `ad_join_admin_user`: An AD user with privileges to join computers to the domain (defaults to doas-libsftp).
*   `ad_join_admin_password`: The password for the `admin_user`. **It is highly recommended to use Ansible Vault to encrypt this variable.**
*   `ad_join_computer_ou`: The organizational unit (OU) in AD where the computer object will be created.
*   `ad_join_create_home_dir`: Whether to enable automatic home directory creation for AD users (true/false).
*   `ad_join_default_shell`: The default shell for AD users (e.g., `/bin/bash`).

### Other Variables (`vars/main.yml`)

*   `ad_join_packages`: A list of required packages to install.
*   `ad_join_sssd_config_file`: Path to the `sssd.conf` file.
*   `ad_join_krb5_config_file`: Path to the `krb5.conf` file.
*   `ad_join_authselect_custom_path`: Path to the custom `authselect` profile directory.
*   `ad_join_authselect_profile_name`: Name of the custom `authselect` profile.

## Example Playbook

```yaml
---
- hosts: your_rocky9_vm
  become: true
  roles:
    - role: ad_join
      vars:
        ad_join_admin_password: "{{ vault_admin_password }}"
