import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.mark.parametrize("file", [
    "/home/deploy/settings.php",
    "/etc/drush/aliases.drushrc.php",
    "/home/deploy/.env.local"
    ])
def test_for_libwww_file_exist(host, file):
    file = host.file(file)

    assert file.exists


@pytest.mark.parametrize("line", [
    "Alias /utils /var/www/discoveryutils_cap/current/public",
    "DocumentRoot /var/www/library_cap/current"
    ])
def test_for_libwww_apache_config(host, line):
    file = host.file("/etc/apache2/sites-available/000-default.conf")

    assert file.contains(line)


@pytest.mark.parametrize("line", [
    "deploy ALL=(ALL) NOPASSWD: /usr/sbin/service apache2 restart",
    "Runas_Alias WWW = www-data",
    "deploy ALL = (WWW) NOPASSWD: ALL",
    "deploy ALL=(ALL) NOPASSWD: /bin/chown -R www-data /var/www/library_cap*",
    "deploy ALL=(ALL) NOPASSWD: /bin/chown -R deploy /var/www/library_cap*"
    ])
def test_for_libwww_sudoer(host, line):
    file = host.file("/etc/sudoers")

    assert file.contains(line)
