import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']
).get_hosts('all')


def test_shibboleth_config_file(host):
    f = host.file('/etc/shibboleth/example-shibboleth2.xml')

    assert f.exists


def test_for_shibd_installation(host):
    command = "sudo shibd -t"
    cmd = host.run(command)

    assert "WARN" in cmd.stdout
