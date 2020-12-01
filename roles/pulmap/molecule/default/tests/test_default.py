import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']
).get_hosts('all')


def test_for_pulmap_directory(host):
    f = host.file('/opt/pulmap/shared/tmp')

    assert f.exists
    assert f.is_directory
    assert f.user == 'deploy'


def test_for_pulmap_googlecloud_config(host):
    f = host.file('/home/deploy/cloud_config')

    assert f.exists
    assert f.is_directory
