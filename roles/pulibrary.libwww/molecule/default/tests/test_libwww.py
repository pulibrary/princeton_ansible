import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_discovery_utils_home_directory(host):
    file = host.file("/var/www/discoveryutils/index.php")

    assert file.exists
