import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.mark.parametrize("path", [
    "/opt/pas/storage",
    "/opt/pas/config",
    "/opt/pas/vendor",
    "/opt/pas/web/cpresources"
    ])
def test_for_pas_code_file_permissions(host, path):
    f = host.file(path)

    assert f.exists
    assert f.user == 'www-data'
    assert f.group == 'www-data'


def test_for_pas_code_env_file(host):
    f = host.file('/opt/pas/.env')

    assert f.exists
    assert f.user == 'www-data'
    assert f.group == 'www-data'
    assert f.contains('ENVIRONMENT="staging"')


def test_for_mysql_user_and_access(host):
    command = "mysql -upas -pchange_this pas -e'show tables'"
    cmd = host.run(command)
    assert "ERROR " not in cmd.stderr
    assert "craft_assets" in cmd.stdout
