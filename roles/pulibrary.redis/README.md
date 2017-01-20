Redis
=========

Installs and configures redis. It is heavily inspired by Geerlingguy's repo but eliminates the references to Centos which we aren't interested in and simple is ALWAYS better

Requirements
------------

This depends on our pulibrary.common role.

Role Variables
--------------

Role varaibles are listed below, along with their defaults:

    redis_conf_path: '/etc/redis/redis.conf'
    redis_port: 6379
    redis_bind_interface: 127.0.0.1
    redis_unixsocket: ''
    redis_timeout: 300
    redis_loglevel: "notice"
    redis_logfile: /var/log/redis/redis-server.log
    redis_databases: 16
    redis_save:
        - 900 1
        - 300 10
        - 60 10000
    redis_rdbcompression: "yes"
    redis_dbfilename: dump.rdb
    redis_dbdir: /var/lib/redis
    redis_maxmemory: 0
    redis_maxmemory_policy: "noeviction"
    redis_maxmemory_samples: 5
    redis_appendonly: "no"
    redis_appendfsync: "everysec"
    redis_includes: []
