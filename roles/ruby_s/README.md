## Ruby

Builds, upgrades, or downgrades Ruby from source, ensuring you have the correct version of Ruby.

### Requirements

None

### Role Variables

Installs the value of `ruby_version_default` by default. If you need a different version of ruby, set `ruby_version_override` using the pattern `ruby-x.y.z`. 

e.g `ruby_version_override: ruby-3.0.0`

This is most reliably set in your `group_vars/<your_role>/[common|main].yml`

### Upgrading from Ruby 2.x installed with apt

If you are upgrading a system from a previous ansible build that used the `ruby` role
to install ruby from the brightbox ruby packages (PPAs) using apt, which is probably
the case for anything at PUL using ruby 2.x:

* In `group_vars/<your project>/[common|main].yml`:
  * If `passenger_ruby` is set, update it to `/usr/local/bin/ruby`. Current default setting in the passenger role is `/usr/bin/ruby` - eventually we should update that!
  * Update these values:
  ```
  # Use Ruby 3.0.3 and install from source
  install_ruby_from_source: true
  ruby_version_override: "ruby-3.0.3"
  bundler_version: "2.3.11"
  passenger_ruby: "/usr/local/bin/ruby"
  ```
* Make sure you update your project to use bundler 2.3.11 and re-generate Gemfile.lock

### Dependencies

None

### Example Playbook

```yaml
- hosts: localhost
  roles:
    - role: ruby_s
```
