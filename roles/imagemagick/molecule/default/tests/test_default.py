import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']
).get_hosts('all')


def test_imagemagick_installed(host):
    command = """identify -list resource"""
    cmd = host.run(command)

    assert 'Resource limits:' in cmd.stdout
    assert 'Width: 214.7MP' in cmd.stdout
    assert 'Height: 214.7MP' in cmd.stdout
    assert 'Area: 1.0737GP' in cmd.stdout
    assert 'Memory: 2GiB' in cmd.stdout
    assert 'Map: 4GiB' in cmd.stdout
    assert 'Disk: 8GiB' in cmd.stdout
