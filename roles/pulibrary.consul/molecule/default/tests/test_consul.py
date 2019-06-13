import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_for_consul_binary(host):
    f = host.file('/usr/local/bin/consul')
    assert f.exists


def test_for_consul_config_directory(host):
    f = host.file('/etc/consul')

    assert f.exists
    assert f.is_directory
    assert f.user == 'consul'
    assert f.group == 'bin'
