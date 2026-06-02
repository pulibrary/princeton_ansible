# Nodejs

By default, this role installs Yarn Classic from the Yarn upstream APT
repository.

```yaml
use_yarn: true
nodejs_yarn_berry_enabled: false
```


To install Yarn Berry instead, enable the Berry flag

```yaml
use_yarn: true
nodejs_yarn_berry_enabled: true
nodejs_yarn_berry_version: "4.15.0"
```

When nodejs_yarn_berry_enabled is true, the role removes the apt-installed
yarn package and installs the pinned Yarn Berry version with Corepack.

This preserves backward compatibility for existing hosts using Yarn Classic
while allowing newer applications to opt into Yarn Berry.

