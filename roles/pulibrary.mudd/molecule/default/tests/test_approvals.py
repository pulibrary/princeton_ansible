import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_for_mudd_rails_config(host):
    f = host.file('/home/deploy/app_configs/mudd-dbs')

    assert f.exists
    assert f.user == 'deploy'
    assert f.group == 'deploy'


def test_for_mudd_is_directory(host):
    f = host.file('/opt/mudd-dbs/shared/tmp')

    assert f.exists
    assert f.is_directory
    assert f.user == 'deploy'
    assert f.group == 'deploy'

def test_for_mudd_database_yml(host):
    f = host.file('/opt/mudd-dbs/shared/config/database.yml')

    assert f.exists
    assert f.user == 'deploy'
    assert f.group == 'deploy'


def test_for_mudd_files(host):
    f = host.file('/etc/logrotate.d/mudd-dbs')

    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'

