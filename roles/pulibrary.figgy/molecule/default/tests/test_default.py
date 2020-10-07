import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']
).get_hosts('all')


@pytest.mark.parametrize("file",
                         ["/mnt/hydra_sources",
                          "/mnt/figgy_binaries",
                          "/mnt/figgy_images",
                          "/mnt/diglibdata",
                          "/mnt/illiad",
                          "/mnt/diglibdata/pudl",
                          "/mnt/diglibdata/hydra_binaries",
                          "/mnt/illiad/images",
                          "/mnt/illiad/ocr_scan",
                          "/mnt/illiad/cdl_scans"
                          ])
def test_for_figgy_mounts_exist(host, file):
    file = host.file(file)

    assert file.exists
