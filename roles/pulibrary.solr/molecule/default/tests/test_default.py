import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']
).get_hosts('all')


def test_solr_directory_ownership(host):
    f = host.file('/solr')

    assert f.exists
    assert f.user == 'deploy'
    assert f.group == 'deploy'


def test_solr_running(host):
    command = """curl --digest -L -D - http://localhost:8983/solr"""
    cmd = host.run(command)

    assert 'HTTP/1.1 200 OK' in cmd.stdout


def test_core_configured(host):
    f = host.file('/solr/data/catalog/core.properties')

    assert f.exists
    assert f.user == 'deploy'
    assert f.group == 'deploy'
