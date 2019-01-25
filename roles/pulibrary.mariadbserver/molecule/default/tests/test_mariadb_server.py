import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.mark.parametrize("name", [
    "python-mysqldb",
    "mariadb-server",
    "automysqlbackup",
    ])
def test_for_mariadb_server_software(host, name):
    pkg = host.package(name)

    assert pkg.is_installed


def test_mariadb_server_listening_port(host):
    socket = host.socket("tcp://127.0.0.1:3306")

    assert socket.is_listening
