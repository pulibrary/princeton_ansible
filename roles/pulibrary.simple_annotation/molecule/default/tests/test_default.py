import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']
).get_hosts('all')


def test_simple_annotation_directory(host):
    f = host.file('/opt/simple_annotation')

    assert f.exists
