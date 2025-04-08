# Ansible Role: ClamAV

Copied from https://github.com/geerlingguy/ansible-role-clamav

[![CI](https://github.com/geerlingguy/ansible-role-clamav/actions/workflows/ci.yml/badge.svg)](https://github.com/geerlingguy/ansible-role-clamav/actions/workflows/ci.yml)

Installs ClamAV on RedHat/CentOS and Debian/Ubuntu Linux servers.

## Requirements

None.

## Role Variables

Available variables are listed below, along with default values (see `defaults/main.yml`):

    clamav_packages:
      - clamav
      - clamav-base
      - clamav-daemon

(Defaults for Debian/Ubuntu shown). List of packages to be installed for ClamAV operations.

    clamav_daemon_localsocket: /var/run/clamav/clamd.ctl
    clamav_daemon_config_path: /etc/clamav/clamd.conf
    clamav_freshclam_daemon_config_path: /etc/clamav/freshclam.conf

Path configuration for ClamAV daemon. These are hardcoded specifically for each OS family (Debian and Red Hat) and cannot be overidden.

    clamav_daemon_configuration_changes:
      - regexp: '^.*Example$'
        state: absent
      - regexp: '^.*LocalSocket .*$'
        line: 'LocalSocket {{ clamav_daemon_localsocket }}'

Changes to make to the configuration file that is read from when ClamAV starts. You need to at least comment the 'Example' line and open a LocalSocket (or `TCPSocket`, e.g. `3310` by default) to get the ClamAV daemon to run.

    clamav_daemon_state: started
    clamav_daemon_enabled: true

Control whether the `clamav-daemon` service is running and/or enabled on system boot.

    clamav_freshclam_configuration_changes:
      - regexp: '^.*HTTPProxyServer .*$'
        line: 'HTTPProxyServer {{ clamav_freshclam_http_proxy_server }}'
      - regexp: '^.*HTTPProxyPort .*$'
        line: 'HTTPProxyPort {{ clamav_freshclam_http_proxy_port }}'

Changes to make to the configuration file that is read from when freshclam starts. You will need to add your HTTP Proxy server configuration here, if you have one.

    clamav_freshclam_daemon_state: started
    clamav_freshclam_daemon_enabled: true

Control whether the `clamav-freshclam` service is running and/or enabled on system boot.

## Dependencies

None.

## Example Playbook

    - hosts: servers
      become: true
      roles:
        - clamav

## License

MIT / BSD

## Author Information

This role was created in 2017 by [Jeff Geerling](https://www.jeffgeerling.com/), author of [Ansible for DevOps](https://www.ansiblefordevops.com/).
