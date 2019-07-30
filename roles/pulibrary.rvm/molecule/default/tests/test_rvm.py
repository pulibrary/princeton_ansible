import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


<<<<<<< HEAD
def test_rvm_file(host):
    f = host.file('/usr/local/rvm')
=======
<<<<<<< HEAD:roles/pulibrary.drush/molecule/default/tests/test_drush.py
def test_drush_file(host):
    file = host.file("/usr/local/bin/drush")

    assert file.exists


def test_hosts_file(host):
    f = host.file('/etc/hosts')
=======
def test_rvm_file(host):
    f = host.file('/usr/local/rvm')
>>>>>>> add rvm tests:roles/pulibrary.rvm/molecule/default/tests/test_rvm.py
>>>>>>> add rvm tests

    assert f.exists
    assert f.user == 'root'
    assert f.group == 'rvm'
