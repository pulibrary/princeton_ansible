#!/bin/bash

set -e -o pipefail

cd $(dirname $0)

./mysql_backup.sh

./purge.sh --really
