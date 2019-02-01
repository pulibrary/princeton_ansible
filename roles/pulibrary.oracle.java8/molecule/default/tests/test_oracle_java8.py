import os
import pytest


import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.mark.parametrize("name", [
    ("oracle-java8-installer"),
    ("ca-certificates"),
    ("oracle-java8-set-default"),
    ])
def test_for_oracle_java8_installer(host, name):
    package = host.package("name")

    assert package.is_installed