import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_is_nginx_installed(host):
    package_nginx = host.package('nginx-common')

    assert package_nginx.is_installed


def test_nginx_config_exists(host):
    nginx_config = host.file('/etc/nginx/nginx.conf')

    assert nginx_config.exists


def test_nginx_user(host):
    user = host.user('www-data')

    assert user.exists
    assert user.group == 'www-data'
    assert user.shell == '/usr/sbin/nologin'
    assert user.home == '/var/www'


def test_http_port(host):
    port = host.socket('tcp://0.0.0.0:80')

    assert port.is_listening
