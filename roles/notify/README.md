## notify

This Ansible role installs and configures [ntfy](https://docs.ntfy.sh/), a simple HTTP-based pub-sub notification service that allows you to send push notifications to your phone or desktop via scripts or webhooks.

### Requirements

  * **Operating System:** Ubuntu (Debian family) - this role is opinionated and only supports Ubuntu
  * **Ansible Version:** 2.9+
  * **Python Packages** `python3-passlib` (installed by role)

### Role variables

#### Required Variables:

The role requires `notify_auth_users_bcrypt` to be defined

#### Default Variables

All configurable variables and their default values are at [defaults/main.yml](defaults/main.yml)

#### Post-Installation

After the roles runs successfully:

  1. ntfy will be listening on the configured port (default: 8066)

  1. Access the web interface at your configured `notify_public_base_url`

  1. Use the configured credentials to authenticate

  1. Create topics and start sending notifications
