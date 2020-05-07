import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_for_dspace_home(host):
    f = host.file('/dspace')

    assert f.exists
    assert f.is_directory
    assert f.user == 'deploy'
    assert f.group == 'deploy'


def test_for_dspace_download(host):
    f = host.file('/opt/dspace-6.3-release/dspace')

    assert f.exists
    assert f.is_directory
    assert f.user == 'deploy'
    assert f.group == 'deploy'


def test_for_dspace_configure(host):
    f = host.file('/opt/dspace-6.3-release/dspace/local.cfg')

    assert f.exists
    assert f.user == 'deploy'
    assert f.group == 'deploy'


def test_for_mvn_package(host):
    f = host.file('/opt/dspace-6.3-release/dspace/target/dspace-installer')

    assert f.exists
    assert f.is_directory
    assert f.user == 'deploy'
    assert f.group == 'deploy'


def test_for_ant_install(host):
    for web_app in ['jspui', 'solr', 'oai', 'rest', 'sword', 'swordv2']:

        f = host.file(f"/dspace/${web_app}")
        assert f.exists
        assert f.is_directory
        assert f.user == 'deploy'
        assert f.group == 'deploy'


def test_for_tomcat_deploy(host):
    for web_app in ['jspui', 'solr', 'oai', 'rest', 'sword', 'swordv2']:

        f = host.file(f"/usr/share/tomcat8/${web_app}")
        assert f.exists
        assert f.is_directory
        assert f.user == 'deploy'
        assert f.group == 'deploy'


def test_dspace_running(host):
    command = """curl --digest -L -D - http://localhost:8080/jspui"""
    cmd = host.run(command)

    assert 'HTTP/1.1 200 OK' in cmd.stdout
