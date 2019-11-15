import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']
).get_hosts('all')


@pytest.mark.parametrize("path", ["/var/local/firestone-renovations",
                                  "/var/local/republic",
                                  "/var/local/milberg",
                                  "/etc/apache2/sites-enabled/000-lib-static-staging1.conf",
                                  "/etc/apache2/sites-enabled/000-milberg-staging.conf"
                                  ])
def test_for_libstatic_code_git_repos(host, path):
    f = host.file(path)

    assert f.exists


def test_for_libstatic_default_disbaled(host):
    f = host.file('/etc/apache2/sites-enabled/000-default.conf')

    assert not f.exists
