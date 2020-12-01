import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_for_dspace_atmire_aliases(host):
    f = host.file('/home/dspace/.aliases.local')

    assert f.exists
    assert f.user == 'dspace'
    assert f.group == 'dspace'
