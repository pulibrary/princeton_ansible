## php

installs and configures php which will install `pulibrary.apache2`

### Role variables

None

### Dependencies

`pulibrary.apache2`

### Example playbook

This is a sample playbook file for deploying the `pulibrary.apache2` role in a localhost

```yaml
---
- hosts: localhost
  become: true
  roles:
    - role: pulibrary.php
  vars:
    apache.servername: localhost
```
