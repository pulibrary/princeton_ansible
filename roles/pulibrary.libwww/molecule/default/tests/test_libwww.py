import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.mark.parametrize("file", [
    "/var/www/discoveryutils/public/index.php",
    "/var/www/library/sites/default/settings.php",
    "/etc/drush/aliases.drushrc.php",
    "/var/www/discoveryutils/vendor/symfony",
    "/var/www/discoveryutils/.env.local"
    ])
def test_for_libwww_file_exist(host, file):
    file = host.file(file)

    assert file.exists


@pytest.mark.parametrize("line", [
    "Alias /utils /var/www/discoveryutils/public",
    "DocumentRoot /var/www/library"
    ])
def test_for_libwww_apache_config(host, line):
    file = host.file("/etc/apache2/sites-available/000-default.conf")

    assert file.contains(line)
