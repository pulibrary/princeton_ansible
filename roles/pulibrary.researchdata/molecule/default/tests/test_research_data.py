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


def test_for_postgressql_user_and_access(host):
    command = r"psql -U researchdata -w researchdata -c '\d'"
    cmd = host.run(command)
    assert "error: " not in cmd.stderr


@pytest.mark.parametrize("line", [
    "deploy ALL=(ALL) NOPASSWD: /usr/sbin/service nginx *",
    "Runas_Alias WWW = www-data",
    "deploy ALL = (WWW) NOPASSWD: ALL",
    "deploy ALL=(ALL) NOPASSWD: " +
    "/bin/chown -R www-data /var/www/researchdata*",
    "deploy ALL=(ALL) NOPASSWD: /bin/chown -R deploy /var/www/researchdata*"
    ])
def test_for_libwww_sudoer(host, line):
    file = host.file("/etc/sudoers")

    assert file.contains(line)
