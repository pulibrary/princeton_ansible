import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']
).get_hosts('all')


def test_hosts_file(host):
    f = host.file('/etc/hosts')

    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'


def test_nginxplus_user(host):
    user = host.user('www-data')

    assert user.exists
    assert user.group == 'www-data'
    assert user.shell == '/usr/sbin/nologin'
    assert user.home == '/var/www'
