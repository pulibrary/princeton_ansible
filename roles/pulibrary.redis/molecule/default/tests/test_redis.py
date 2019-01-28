import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')


@pytest.mark.parametrize("name", [
    "redis-server",
    "redis-tools",
    "python-redis",
    ])
def test_commonly_needed_build_files(host, name):
    pkg = host.package(name)

    assert pkg.is_installed


def test_redis_server_listening_port(host):
    socket = host.socket("tcp://0.0.0.0:6379")

    assert socket.is_listening
