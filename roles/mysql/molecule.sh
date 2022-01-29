#!/bin/bash

# ./molecule.sh role

export DOCKER_HOST=${MOLECULE_DOCKER_HOST:-"tcp://localhost:2376"}
export DOCKER_TLS_VERIFY=${MOLECULE_DOCKER_TLS_VERIFY:-1}
#export DOCKER_TLS_HOSTNAME=${MOLECULE_DOCKER_TLS_HOSTNAME:-"toto.com"}
export DOCKER_CERT_PATH=${MOLECULE_DOCKER_CERT_PATH:-"/etc/docker/ssl"}

cd "../mysql" && molecule test
