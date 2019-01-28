import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.mark.parametrize("name", [
    "ruby-switch",
    "ruby2.4",
    "ruby2.4-dev",
    ])
def test_for_ruby_package_installs(host, name):
    pkg = host.package(name)

    assert pkg.is_installed
