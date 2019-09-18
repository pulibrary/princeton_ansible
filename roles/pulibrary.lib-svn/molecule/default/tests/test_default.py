import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_lib_svn_home_dir(host):
    f = host.file('/var/svn/libsvn')

    assert f.exists
