import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_cantaloupe_symlink_file(host):
    f = host.file('/opt/cantaloupe')

    assert f.exists
    assert f.user == 'deploy'
    assert f.group == 'deploy'
