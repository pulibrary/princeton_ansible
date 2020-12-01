import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']
).get_hosts('all')


def test_hosts_file(host):
    f = host.file('/etc/hosts')

    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'


@pytest.mark.parametrize("name", [
    "python3-mysqldb",
    "python-pymysql",
    "percona-server-server-5.7",
    ])
def test_for_percona_server_software(host, name):
    pkg = host.package(name)

    assert pkg.is_installed


def test_for_mysql_user_and_access(host):
    command = "mysql -umy_user -pmy_pass my_db -e'show tables'"
    cmd = host.run(command)
    assert "ERROR " not in cmd.stderr
