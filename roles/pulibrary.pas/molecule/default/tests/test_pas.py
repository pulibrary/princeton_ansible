import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.mark.parametrize("name", [
    "php7.2",
    "php7.2-curl",
    "php7.2-gd",
    "php7.2-json",
    "php7.2-mbstring",
    "php7.2-mysql",
    "php7.2-zip",
    "php7.2-intl",
    "cifs-utils",
    "zip"
    ])
def test_for_pas_php_software(host, name):
    pkg = host.package(name)

    assert pkg.is_installed


@pytest.mark.parametrize("module", [
    "remoteip",
    "proxy",
    "proxy_fcgi",
    "php7"
    ])
def test_for_pas_apache2_modules(host, module):
    module_name = module+"_module"
    command = "apache2ctl -M |grep '"+module_name+"'"
    cmd = host.run(command)
    assert module_name+" " in cmd.stdout


@pytest.mark.parametrize("module", [
    "sass",
    "grunt-cli"
    ])
def test_for_pas_node_modules(host, module):
    command = "npm ls -g '"+module+"'"
    cmd = host.run(command)
    assert module in cmd.stdout


@pytest.mark.parametrize("line", [
    "DocumentRoot /opt/pas/web"
    ])
def test_for_pas_apache2_sites(host, line):
    site_file = host.file("/etc/apache2/sites-available/000-default.conf")
    assert site_file.contains(line)


def test_for_pas_app_dir(host):
    f = host.file('/opt/pas')
    assert f.exists
