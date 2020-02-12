import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']
).get_hosts('all')


def test_postgresql_server_listening_port(host):
    socket = host.socket("tcp://127.0.0.1:5432")

    assert socket.is_listening


# def test_for_postgresql_user_and_access(host):
#    command = "psql -U test_user_with_db -W test_db -l"
#    cmd = host.run(command)
#    assert "ERROR " not in cmd.stderr


def test_hosts_file(host):
    f = host.file('/etc/hosts')

    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'
