import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_for_archivesspace_is_directory(host):
    f = host.file('/opt/archivesspace')

    assert f.exists
    assert f.is_directory
    assert f.user == 'deploy'
    assert f.group == 'deploy'
