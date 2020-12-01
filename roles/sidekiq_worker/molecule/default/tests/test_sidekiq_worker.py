import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_sidekiq_workers_systemd_service_file(host):
    f = host.file('/etc/systemd/system/sidekiq-workers.service')

    assert f.exists
    assert f.user == 'root'
    assert f.group == 'root'
