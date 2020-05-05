import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']
).get_hosts('all')


def test_pgbouncer_ini_file(host):
    f = host.file('/etc/pgbouncer/pgbouncer.ini')

    assert f.exists
    assert f.user == 'postgres'
    assert f.group == 'postgres'


def test_for_postgresql_access(host):
    command = "sudo -u postgres psql -l"
    cmd = host.run(command)

    assert "ERROR " not in cmd.stderr
    assert "awesome_db" in cmd.stdout
