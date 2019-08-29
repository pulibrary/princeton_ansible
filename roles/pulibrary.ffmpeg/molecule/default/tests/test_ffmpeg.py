import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_is_ffmpeg_installed(host):
    pkg = host.package('ffmpeg')

    assert pkg.is_installed
