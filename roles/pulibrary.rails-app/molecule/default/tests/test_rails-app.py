import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_for_rails_app_rails_config(host):
    f = host.file('/home/deploy/app_configs/rails_app')

    assert f.exists
    assert f.user == 'deploy'
    assert f.group == 'deploy'


def test_for_rails_app_is_directory(host):
    f = host.file('/opt/rails_app/shared/tmp')

    assert f.exists
    assert f.is_directory
    assert f.user == 'deploy'
    assert f.group == 'deploy'


def test_for_rails_app_logrotate(host):
    f = host.file('/etc/logrotate.d/rails_app')

    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'
