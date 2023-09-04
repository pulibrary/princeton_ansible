#!/bin/bash

set -e -o pipefail

cd $(dirname $0)

./mysql_backup.sh

./prune.sh --really
