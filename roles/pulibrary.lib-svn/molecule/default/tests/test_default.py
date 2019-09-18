import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_lib_svn_home_dir(host):
    f = host.file('/srv/svn/repos/libsvn')

    assert f.exists
    assert f.user == 'svn'
    assert f.group == 'svn'
