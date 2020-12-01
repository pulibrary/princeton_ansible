import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.mark.parametrize("name", [
    "php7.2-gd",
    "php7.2-xml",
    "php7.2-mbstring",
    ])
def test_for_matomo_prereq_software(host, name):
    pkg = host.package(name)

    assert pkg.is_installed


def test_for_matomo_js_file(host):
    file = host.file("/var/www/piwik/matomo.js")

    assert file.exists
