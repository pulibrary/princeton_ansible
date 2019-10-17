import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']
).get_hosts('all')


def test_hosts_file(host):
    f = host.file('/etc/hosts')

    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'


@pytest.mark.parametrize("name", [
    "postgresql-client-12",
    "python3-psycopg2",
    ])
def test_for_postgres_software(host, name):
    pkg = host.package(name)

    assert pkg.is_installed
