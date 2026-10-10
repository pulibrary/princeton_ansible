# Loadtest

Installs [Apache JMeter](https://jmeter.apache.org/) and
[Grafana k6](https://k6.io/) on a load-generation host and makes both
available to the deploy user.

* JMeter is unpacked to `/opt/apache-jmeter-<version>`, linked as `/opt/jmeter`
  and `/usr/local/bin/jmeter`. `JMETER_HOME` is set in `/etc/profile.d/jmeter.sh`
  and the JVM heap in `bin/setenv.sh`.
* k6 is unpacked from the upstream release tarball and linked as `/usr/local/bin/k6`.
* `/home/<loadtest_user>/loadtests/{jmeter,k6,results}` is created and owned by
  the deploy user, with a sample `k6/smoke.js` and a README.

Both downloads are pinned by checksum. To upgrade, bump the version and the
checksum(s) together in `defaults/main.yml`.

JMeter needs Java; run the `openjdk` role first (see `playbooks/loadtest.yml`).

## Variables

| Variable | Default |
|---|---|
| `loadtest_jmeter_version` | `5.6.3` |
| `loadtest_jmeter_sha512` | sha512 of the 5.6.3 tarball |
| `loadtest_jmeter_heap` | `-Xms1g -Xmx2g -XX:MaxMetaspaceSize=256m` |
| `loadtest_jmeter_user_properties` | `["resultcollector.action_if_file_exists=DELETE"]` |
| `loadtest_k6_version` | `2.3.0` |
| `loadtest_k6_checksums` | sha256 per architecture (`amd64`, `arm64`) |
| `loadtest_user` | `{{ deploy_user \| default('deploy') }}` |
| `loadtest_workspace` | `/home/{{ loadtest_user }}/loadtests` |

## Usage

    ansible-playbook playbooks/loadtest.yml                         # loadtest1 (staging)
    ansible-playbook playbooks/loadtest.yml -e runtime_env=production
