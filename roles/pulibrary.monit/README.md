## pulibrary monit

Installs monit

## Role variables

```
---
# How often in seconds should monit check the process?
monit_interval: 60

# How many seconds delay should monit wait before monitoring on the first time?
monit_start_delay: 30 # 0 to disable

# Where should monit log to?
monit_logfile: syslog facility log_daemon

# Where should events be written in case the mail server is down?
monit_event_path: /var/lib/monit/events

# Should e-mail alerts be sent?
monit_alerts_on: true
```

#### Warning

The role as currently configured will monitor a solr process (this coupling will
be broken once we have a better solr role) This likely to be the only place we
use monit 
