import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_for_deploy_group(host):
    group = host.group("deploy")

    assert group.exists


def test_for_deploy_user(host):
    user = host.user("deploy")

    assert user.exists


def test_for_deploy_ssh_config(host):
    f = host.file('/home/deploy/.ssh/config')

    assert f.exists
