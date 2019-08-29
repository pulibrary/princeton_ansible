import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_for_approvals_rails_config(host):
    f = host.file('/home/deploy/app_configs/approvals')

    assert f.exists
    assert f.user == 'deploy'
    assert f.group == 'deploy'


def test_for_approvals_is_directory(host):
    f = host.file('/opt/approvals/shared/tmp')

    assert f.exists
    assert f.is_directory
    assert f.user == 'deploy'
    assert f.group == 'deploy'


def test_for_approvales_files(host):
    f = host.file('/etc/logrotate.d/approvals')

    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'


def test_for_approvals_mnt_directory(host):
    f = host.file('/mnt/dms-smbserve')

    assert f.exists
    assert f.is_directory
