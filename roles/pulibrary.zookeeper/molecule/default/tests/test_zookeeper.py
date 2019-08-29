import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.mark.parametrize("name", [
    "zookeeper",
    "zookeeperd",
    ])
def test_commonly_needed_build_files(host, name):
    pkg = host.package(name)

    assert pkg.is_installed
