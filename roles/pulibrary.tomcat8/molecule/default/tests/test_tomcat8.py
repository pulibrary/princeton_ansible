import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.mark.parametrize("name", [
    "tomcat8"
    ])
def test_for_tomcat8(host, name):
    pkg = host.package(name)

    assert pkg.is_installed


def test_tomcat8_listening_http(host):
    socket = host.socket('tcp://0.0.0.0:8080')

    assert socket.is_listening


def test_hosts_file(host):
    f = host.file('/etc/hosts')

    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'
