## Ruby

Builds Ruby from source

### Requirements

None

### Role Variables

if you need a different version of ruby use the example on

`defaults/main.yml`

e.g `desired_ruby_version: "3.0.0"` and `ruby_version_override: ruby-3.0.0`

this is most reliably set in your `group_vars/<your_role>/vars.yml`

### Upgrading from Ruby 2.x

If you are upgrading a system from a previous ansible build that used brightbox
ruby packages (which is probably the case for anything at PUL using ruby 2.x): 

* In `group_vars/<your project>/[common|main].yml`:
  * If `passenger_ruby` is set, remove it. The default value is `/usr/local/bin/ruby` and that's what we want.
  * Update these values:
  ```
  # Use Ruby 3.0.3 and install from source
  install_ruby_from_source: true
  ruby_version_override: "ruby-3.0.3"
  bundler_version: "2.3.11"
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
