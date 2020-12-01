import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.mark.parametrize("name", [
    "libaio1",
    "build-essential",
    "unzip",
    ])
def test_dependencies_for_oracle_client(host, name):
    pkg = host.package(name)

    assert pkg.is_installed


def test_oracle_client_directory(host):
    file = host.file("/opt/oracle")

    assert file.exists
