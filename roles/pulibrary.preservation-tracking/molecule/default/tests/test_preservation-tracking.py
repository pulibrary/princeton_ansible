import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_for_approvals_rails_config(host):
    f = host.file('/home/deploy/app_configs/preservation_tracking')

    assert f.exists
    assert f.user == 'deploy'
    assert f.group == 'deploy'


def test_for_approvals_is_directory(host):
    f = host.file('/opt/preservation_tracking/shared/tmp')

    assert f.exists
    assert f.is_directory
    assert f.user == 'deploy'
    assert f.group == 'deploy'


def test_for_approvales_files(host):
    f = host.file('/etc/logrotate.d/preservation_tracking')

    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'
