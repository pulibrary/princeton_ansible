import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.mark.parametrize("name", [
    "php7.2",
    "php7.2-dev",
    "php7.2-curl",
    ])
def test_for_php7_software(host, name):
    pkg = host.package(name)

    assert pkg.is_installed


def test_hosts_file(host):
    f = host.file('/etc/hosts')

    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'
