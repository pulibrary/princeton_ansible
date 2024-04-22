import os
import pytest

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


@pytest.mark.parametrize("line",
                         ["'^example.com$'",
                          "'^example-also.com$'"])
def test_for_libwww_sudoer(host, line):
    file = host.file("//home/deploy/settings.php")

    assert file.contains(line)
