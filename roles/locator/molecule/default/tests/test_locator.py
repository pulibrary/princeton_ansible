import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_db_config_file(host):
    f = host.file('/home/deploy/db_config.php')

    assert f.exists
    assert f.user == 'deploy'
    assert f.group == 'deploy'


def test_var_www_file(host):
    f = host.file('/var/www')

    assert f.exists
    assert f.user == 'deploy'
    assert f.group == 'deploy'
