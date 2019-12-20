import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']
).get_hosts('all')


def test_saxon9_xquery_file(host):
    f = host.file('/usr/local/bin/saxon9he-xquery')

    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'


def test_saxon9_xslt_file(host):
    f = host.file('/usr/local/bin/saxon9he-xslt')

    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'
