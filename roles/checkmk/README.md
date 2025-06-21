Checkmk Local
=========

This role will be used for defaults for checkmk local scripts

Requirements
------------

Role Variables
--------------

variables for checkmk_log_monitor, add these to `group_vars/app_name/environment.yml` or `rolename/vars/main.yml`

| Variable                    | Default                                      | Description                                        |
|-----------------------------|----------------------------------------------|----------------------------------------------------|
| `log_growth_logfile`        | `/var/log/myapp/app.log`                     | Path to the log file to monitor.                   |
| `log_growth_statefile`      | `/var/lib/check_mk_agent/state/app.log.size` | Path to store previous file size state.            |
| `log_growth_interval`       | `300`                                        | Agent execution interval in seconds.               |
| `log_growth_warn_mb_per_hour` | `20`                                       | Warning threshold in MB/hour.                      |
| `log_growth_crit_mb_per_hour` | `30`                                       | Critical threshold in MB/hour.                     |

Dependencies
------------

Usage
----------------

```yaml
- hosts: all
  roles:
    - role: checkmk
      vars:
        log_growth_logfile: "/var/log/other/app.log"
        log_growth_interval: 600
        log_growth_warn_mb_per_hour: 50
        log_growth_crit_mb_per_hour: 100
```

After deployment:

1. The script is placed at `/usr/lib/check_mk_agent/local/log_growth.sh`.
2. The CheckMK agent will run it on its next execution, creating a `log_growth` service.

## License

License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a website (HTML is not allowed).
