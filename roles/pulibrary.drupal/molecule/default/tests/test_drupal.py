import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_drupal_home_directory(host):
    file = host.file("/var/www/drupal/index.php")

    assert file.exists
