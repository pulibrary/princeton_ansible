import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_is_apache_installed(host):
    pkg = host.package('apache2')

    assert pkg.is_installed


def test_apache_listening_http(host):
    socket = host.socket('tcp://0.0.0.0:8081')

    assert socket.is_listening
