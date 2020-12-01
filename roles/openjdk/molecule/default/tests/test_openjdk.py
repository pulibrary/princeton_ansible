import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_for_openjdk_install(host):
    package = host.package("openjdk-8-jdk-headless")

    assert package.is_installed
