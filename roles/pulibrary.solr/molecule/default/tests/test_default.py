import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']
).get_hosts('all')


def test_hosts_file(host):
    f = host.file('/etc/hosts')

    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'


def test_solr_running(host):
    command = """curl --digest -L -D - http://localhost:8983/solr"""
    cmd = host.run(command)

    assert 'HTTP/1.1 200 OK' in cmd.stdout
