import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.mark.parametrize("name", [
    "postgresql-11",
    "postgresql-client-11",
    "postgresql-client-common",
    "postgresql-common",
    "postgresql-server-dev-11"
    ])
def test_for_postgresql_software(host, name):
    pkg = host.package(name)

    assert pkg.is_installed
