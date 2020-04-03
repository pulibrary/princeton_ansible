#!/usr/bin/env fish
# export our environment
set -x ANSIBLE_VAULT_PASSWORD_FILE (command -v lastpass-ansible)
# retain our env for 9 hours
set -x LPASS_AGENT_TIMEOUT 32400
