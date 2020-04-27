import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']
).get_hosts('all')


def test_for_adoptopenjdk_rep_file(host):
    f = host.file('/etc/apt/sources.list.d/adoptopenjdk_role.list')

    assert f.exists
    assert f.user == 'root'
