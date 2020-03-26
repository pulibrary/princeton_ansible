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


def test_solr_core_running(host):
    command = """curl http://localhost:8983/solr/admin/cores?action=STATUS"""
    cmd = host.run(command)

    assert 'pulfalight-staging' in cmd.stdout


def test_solr_config_installed(host):
    command = """curl http://localhost:8983/solr/pulfalight-staging/config"""
    cmd = host.run(command)

    assert 'collection_title_tesim^150' in cmd.stdout
