import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


def test_geoserver_war_file(host):
    f = host.file('/var/lib/tomcat8/webapps/geoserver.war')

    assert f.exists
    assert f.user == 'root'
