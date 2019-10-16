import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_if_pulfa_dir_created(host):
    pulfa_dir = host.dir('/var/opt/pulfa')

    assert pulfa_dir.exists
