## Ruby

Installs Ruby release 2.4.3 and the development libraries of Ruby.

### Requirements

None

### Role Variables

None

### Dependencies

None

### Example Playbook

```yaml
- hosts: localhost
  roles:
    - role: pulibrary.ruby
```

### Notes
#### Bundler
- Currently, Bundler must be downgraded to release 1.16.0 in order to support the usage of [Webpacker](https://github.com/rails/webpacker)
- It looks like we can try using the latest bundler again [once we're on ruby 2.5.x](https://github.com/bundler/bundler/issues/6227)
