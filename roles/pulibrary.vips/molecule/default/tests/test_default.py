import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_vips(host):
    cmd = host.run("vips --version")

    assert 'vips-8.9.1' in cmd.stdout
