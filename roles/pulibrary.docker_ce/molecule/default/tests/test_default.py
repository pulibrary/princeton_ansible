import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']
).get_hosts('all')


def test_docker_user(host):
    user = host.user('docker')

    assert user.exists


def test_docker_compose_file(host):
    file = host.file('/usr/local/bin/docker-compose')

    assert file.exists
    assert file.user == 'docker'
    assert file.group == 'docker'


def test_if_docker_installed(host):
    pkg = host.package('docker-ce')

    assert pkg.is_installed
