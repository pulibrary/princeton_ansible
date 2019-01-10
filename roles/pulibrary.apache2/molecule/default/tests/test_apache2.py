import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_hosts_file(host):
    f = host.file('/etc/hosts')

    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'


def test_is_apache_installed(host):
    package_apache = host.package('apache2')

    assert package_apache.is_installed


def test_apache_listening_http(host):
    socket = host.socket('tcp://0.0.0.0:80')

    assert socket.is_listening
