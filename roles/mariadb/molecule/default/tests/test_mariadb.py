import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.mark.parametrize("name", [
    "python-mysqldb",
    "mysql-client",
    ])
def test_for_mysql_client_software(host, name):
    pkg = host.package(name)

    assert pkg.is_installed


def test_for_mysql_user_and_access(host):
    command = "mysql -usome_user -pchange_me some_database -e'show tables'"
    cmd = host.run(command)
    assert "ERROR " not in cmd.stderr


@pytest.mark.parametrize("file",
                         ["/home/deploy/sql/permissive.sql",
                          "/home/deploy/sql/set_permission.sh",
                          "/home/deploy/.my.cnf",
                          ])
def test_for_libwww_file_exist(host, file):
    file = host.file(file)
    assert file.exists
