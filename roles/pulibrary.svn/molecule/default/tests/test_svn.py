import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.mark.parametrize("name", [
    "libapache2-mod-svn",
    ])
def test_for_svn_software(host, name):
    pkg = host.package(name)

    assert pkg.is_installed
