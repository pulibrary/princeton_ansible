import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']
).get_hosts('all')


@pytest.mark.parametrize("path", ["/var/local/firestone-renovations",
                                  "/var/local/republic",
                                  "/var/local/milberg",
                                  "/var/local/capping_liberty",
                                  "/var/local/pathebaby",
                                  "/var/local/thankful_nation",
                                  "/var/local/jameslyon",
                                  "/var/local/njmaps",
                                  "/var/local/versailles",
                                  "/etc/apache2/sites-enabled/000-lib-static-staging1.conf",
                                  "/etc/apache2/sites-enabled/000-milberg-staging.conf"
                                  ])
def test_for_libstatic_code_git_repos(host, path):
    f = host.file(path)

    assert f.exists


def test_for_libstatic_default_disbaled(host):
    f = host.file('/etc/apache2/sites-enabled/000-default.conf')

    assert not f.exists


@pytest.mark.parametrize("line", ['<Directory "/var/local/firestone-renovations">',
                                  '<Directory "/var/local/republic">',
                                  '<Directory "/var/local/capping_liberty">',
                                  '<Directory "/var/local/pathebaby">',
                                  '<Directory "/var/local/thankful_nation">',
                                  '<Directory "/var/local/jameslyon">',
                                  '<Directory "/var/local/njmaps">',
                                  '<Directory "/var/local/versailles">',
                                  'Alias /renovations /var/local/firestone-renovations',
                                  'Alias /republic /var/local/republic',
                                  'Alias /capping-liberty /var/local/capping_liberty',
                                  'Alias /pathebaby /var/local/pathebaby',
                                  'Alias /thankful-nation /var/local/thankful_nation',
                                  'Alias /jameslyon /var/local/jameslyon',
                                  'Alias /njmaps /var/local/njmaps',
                                  'Alias /versailles /var/local/versailles'
                                  ])
def test_for_sites_in_apache_config(host, line):
    file = host.file("etc/apache2/sites-enabled/000-lib-static-staging1.conf")

    assert file.contains(line)
