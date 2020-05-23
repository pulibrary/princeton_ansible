import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']
).get_hosts('all')


def test_dot_env_file(host):
    f = host.file('/opt/dispatch-docker/.env')

    assert f.exists
