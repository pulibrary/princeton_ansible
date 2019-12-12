#!/usr/bin/env bash
# export our environment
ANSIBLE_VAULT_PASSWORD_FILE="$(command -v lastpass-ansible)"
export ANSIBLE_VAULT_PASSWORD_FILE
# retain our env for 9 hours
LPASS_AGENT_TIMEOUT="32400"
export LPASS_AGENT_TIMEOUT
