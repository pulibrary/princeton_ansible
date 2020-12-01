import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.mark.parametrize("name", [
    "samba-common",
    "samba",
    ])
def test_for_samba_packages(host, name):
    pkg = host.package(name)

    assert pkg.is_installed


def test_for_hr_mnt_directory(host):
    f = host.file('/mnt/dms-smbserve')

    assert f.exists
    assert f.is_directory
