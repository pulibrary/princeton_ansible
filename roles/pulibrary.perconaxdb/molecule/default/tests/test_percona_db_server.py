import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.mark.parametrize("name", [
    "percona-xtradb-cluster-57",
    "percona-xtradb-cluster-client-5.7",
    "percona-xtradb-cluster-common-5.7",
    "percona-xtradb-cluster-server-5.7",
    "percona-xtrabackup-24"
    ])
def test_for_pas_php_software(host, name):
    pkg = host.package(name)

    assert pkg.is_installed


def test_hosts_file(host):
    f = host.file('/etc/hosts')

    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'
