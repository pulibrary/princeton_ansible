import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_ojs_symlink_file(host):
    f = host.file('/var/www/ojs')

    assert f.exists


def test_for_shibboleth_config(host):
    f = host.file('/etc/shibboleth/shibboleth2.xml')

    assert f.exists


def test_for_ojs_db_access(host):
    command = "sudo -u postgres psql -l"
    cmd = host.run(command)

    assert "ERROR " not in cmd.stderr
    assert "ojs_db" in cmd.stdout
