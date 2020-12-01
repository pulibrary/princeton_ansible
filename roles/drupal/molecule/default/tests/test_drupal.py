import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.mark.parametrize("line", [
    "deploy ALL=(ALL) NOPASSWD: /usr/sbin/service apache2 *",
    "Runas_Alias WWW = www-data",
    "deploy ALL = (WWW) NOPASSWD: ALL",
    "deploy ALL=(ALL) NOPASSWD: /bin/chown -R www-data /var/www/drupal*",
    "deploy ALL=(ALL) NOPASSWD: /bin/chown -R deploy /var/www/drupal*"
    ])
def test_for_libwww_sudoer(host, line):
    file = host.file("/etc/sudoers")

    assert file.contains(line)


@pytest.mark.parametrize("file", [
    "/home/deploy/settings.php",
    "/etc/drush/aliases.drushrc.php"
    ])
def test_for_libwww_file_exist(host, file):
    file = host.file(file)

    assert file.exists


@pytest.mark.parametrize("name", [
    "php7.2",
    "php7.2-common",
    "php7.2-mbstring",
    "sendmail"
    ])
def test_for_pas_php_software(host, name):
    pkg = host.package(name)

    assert pkg.is_installed
