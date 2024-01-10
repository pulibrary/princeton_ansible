Redis Role
=========

This role installs a redis server. If your application only needs to connect to
the central redis instance, you don't need to run this role.

### Connecting to the central redis

To connect to the central redis instance, define a variable `central_redis_db` and
give it a number between 1 and 15 that hasn't been used yet for the central host
you're connecting to. Don't use database
0, which is the default database in case one is not specified. To find an unused
number, grep the group_vars directory for `central_redis_db` /
`central_redis_host` pairs (example `ag` command below). Once you've
identified a db number for your application you can set it to an environment
variable that your application will access in its redis or sidekiq
configuration.

You also need to have your application install the redis-tools package.

For good measure, add your app to the list below to help us track which
applications are using the central redis hosts.

Example configuration in a group_vars file:

```
rails_app_dependencies:
  - redis-tools
central_redis_host: 'lib-redis-prod1.princeton.edu'
central_redis_db: '1'
rails_app_vars:
  - name: PULFALIGHT_REDIS_URL
    value: '{{central_redis_host}}'
  - name: PULFALIGHT_REDIS_DB
    value: '{{central_redis_db}}'
```

With this configuration we can easily search for used host / db combinations
with, e.g., `ag central_redis.*: group_vars`

#### Apps using central redis
- orangelight
- pulfalight
- libwww
    - currently configured using a "prefix" strategy. This may mean it's using
        database 0. Some relevant info:
        - https://docs.spring.io/spring-data/redis/docs/1.8.0.RELEASE/api/org/springframework/data/redis/cache/RedisCachePrefix.html
        - https://stackoverflow.com/questions/16819514/stats-of-elements-with-a-prefix-in-redis


Requirements
------------


Role Variables
--------------


Dependencies
------------


Example Playbook
----------------

Including an example of how to use your role (for instance, with variables
passed in as parameters) is always nice for users too:

    - hosts: servers
      roles:
         - { role: roles/redis }

License
-------

MIT

Author Information
------------------

An optional section for the role authors to include contact information, or a
website (HTML is not allowed).
