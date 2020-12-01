import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_if_elasticsearch_installed(host):
    pkg = host.package('elasticsearch')

    assert pkg.is_installed


def test_if_elasticsearch_listening_http(host):
    socket = host.socket('tcp://127.0.0.1:9200')

    assert socket.is_listening
