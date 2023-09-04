#!/bin/bash

set -e -o pipefail

cd $(dirname $0)

./pg_backup.sh

./purge.sh --really
