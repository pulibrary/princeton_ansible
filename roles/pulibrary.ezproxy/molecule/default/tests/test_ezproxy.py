import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_ezproxy_directory(host):
    file = host.file("/var/local/ezproxy")

    assert file.exists
    assert file.is_directory
