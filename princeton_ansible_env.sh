#!/usr/bin/env bash
# Princeton Ansible Environment Setup for Devbox
# This script is automatically executed when entering the Devbox shell
# but can also be sourced manually if needed

# Export our environment
ANSIBLE_VAULT_PASSWORD_FILE="$(command -v lastpass-ansible)"
export ANSIBLE_VAULT_PASSWORD_FILE

# Retain our env for 9 hours
LPASS_AGENT_TIMEOUT="32400"
export LPASS_AGENT_TIMEOUT

# Protect vault commits
./bin/setup

# Optional: Display environment info
echo "Ansible environment configured:"
echo "  ANSIBLE_VAULT_PASSWORD_FILE: $ANSIBLE_VAULT_PASSWORD_FILE"
echo "  LPASS_AGENT_TIMEOUT: $LPASS_AGENT_TIMEOUT (9 hours)"
