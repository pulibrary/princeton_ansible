# Signoz

Ansible role to install and configure the SigNoz observability platform, including:

- **Zookeeper** (for ClickHouse coordination)
- **ClickHouse** (time-series backend)
- **SigNoz Schema Migrator**
- **SigNoz Server**
- **SigNoz OTel Collector**

---

## Requirements

- **Platform**: Debian or Ubuntu
- **Internet Access**: to download packages, binaries, and Docker images
- **Ports**:
  - Zookeeper: `2181`
  - ClickHouse: `9000`
  - OTLP (gRPC/HTTP): `4317`, `4318`
  - Jaeger: `14250`, `14268`
  - Collector health & debug: `13133`, `55679`, `1777`

---

## Role Variables

Defined in `roles/signoz/defaults/main.yml`:

| Variable                        | Default                                                                                                                                      | Description                                                                   |
| ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| `clickhouse_repo_key_url`       | `https://packages.clickhouse.com/rpm/lts/repodata/repomd.xml.key`                                                                            | URL to fetch ClickHouse GPG key                                               |
| `clickhouse_repo`               | `deb [signed-by=/usr/share/keyrings/clickhouse-keyring.gpg arch={{ ansible_architecture }}] https://packages.clickhouse.com/deb stable main` | APT repo for ClickHouse                                                       |
| `zookeeper_version`             | `3.8.4`                                                                                                                                      | Apache Zookeeper version                                                      |
| `signoz_version`                | `latest`                                                                                                                                     | SigNoz server release                                                         |
| `signoz_otel_collector_version` | `latest`                                                                                                                                     | SigNoz OTel Collector release                                                 |
| `signoz_install_dir`            | `/opt/signoz`                                                                                                                                | Installation directory for SigNoz server                                      |
| `signoz_data_dir`               | `/var/lib/signoz`                                                                                                                            | Data directory for SigNoz server                                              |
| `signoz_user`                   | `signoz`                                                                                                                                     | System user to run SigNoz processes                                           |
| `clickhouse_dsn`                | `tcp://localhost:9000?password=password`                                                                                                     | DSN for the SigNoz migrator and server                                        |
| `clickhouse_password`           | *n/a*                                                                                                                                        | Password part of DSN (used in collector exporter config; define in inventory) |
| `signoz_jwt_secret`             | `secret`                                                                                                                                     | JWT signing key for SigNoz                                                    |

---

## Dependencies

None. This role installs and configures all required components.

---

## Example Playbook

```yaml
- hosts: signoz
  become: true
  roles:
    - role: signoz
      vars:
        clickhouse_password: "supersecret"
        clickhouse_dsn: "tcp://localhost:9000?password=supersecret"
        signoz_jwt_secret: "myjwtsecret"
```

---

## License

[MIT](LICENSE)

## Author

- pulibrary
