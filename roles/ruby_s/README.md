## Ruby

Builds Ruby from source

### Requirements

None

### Role Variables

if you need a different version of ruby use the example on

`defaults/main.yml`

e.g `desired_ruby_version: "3.0.0"` and `ruby_version_override: ruby-3.0.0`

this is most reliably set in your `group_vars/<your_role>/vars.yml`

### Dependencies

None

### Example Playbook

```yaml
- hosts: localhost
  roles:
    - role: ruby_s
```
