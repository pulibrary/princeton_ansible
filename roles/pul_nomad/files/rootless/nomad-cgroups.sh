#!/bin/sh
set -e
mkdir -p /sys/fs/cgroup/nomad.slice/reserve.slice /sys/fs/cgroup/nomad.slice/share.slice
chown -R nomad:nomad /sys/fs/cgroup/nomad.slice
