import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_hosts_file(host):
    f = host.file('/etc/hosts')

    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'


def test_for_recap_apache_config(host):
    file = host.file("/etc/apache2/sites-available/000-default.conf")

    assert file.contains("DocumentRoot /var/www/recap_cap/current")


@pytest.mark.parametrize("line", [
    "deploy ALL=(ALL) NOPASSWD: /usr/sbin/service apache2 *",
    "Runas_Alias WWW = www-data",
    "deploy ALL = (WWW) NOPASSWD: ALL",
    "deploy ALL=(ALL) NOPASSWD: /bin/chown -R www-data /var/www/recap_cap*",
    "deploy ALL=(ALL) NOPASSWD: /bin/chown -R deploy /var/www/recap_cap*"
    ])
def test_for_libwww_sudoer(host, line):
    file = host.file("/etc/sudoers")

    assert file.contains(line)
