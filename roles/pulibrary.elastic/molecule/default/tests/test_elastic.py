import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_elastic_package_installation(host):
    package = host.package("elasticsearch")

    assert package.is_installed


def test_apache_listening_http(host):
    socket = host.socket('tcp://0.0.0.0:9200')

    assert socket.is_listenin
