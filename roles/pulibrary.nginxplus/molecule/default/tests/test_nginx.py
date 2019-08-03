import os
import time

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_nginxplus_installed(host):
    package_nginx = host.package('nginx')

    assert package_nginx.is_installed


def test_nginxplus_config_exists(host):
    nginx_config = host.file('/etc/nginx/nginx.conf')

    assert nginx_config.exists


def test_nginxplus_user(host):
    user = host.user('www-data')

    assert user.exists
    assert user.group == 'www-data'
    assert user.shell == '/usr/sbin/nologin'
    assert user.home == '/var/www'
