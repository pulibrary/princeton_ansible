#!/usr/bin/env fish
# Princeton Ansible Environment Setup for Devbox (Fish shell)
# This script can be sourced when using fish shell

# Export our environment
set -x ANSIBLE_VAULT_PASSWORD_FILE (command -v lastpass-ansible)

# Retain our env for 9 hours
set -x LPASS_AGENT_TIMEOUT 32400

# Protect vault commits
./bin/setup

# Optional: Display environment info
echo "Ansible environment configured:"
echo "  ANSIBLE_VAULT_PASSWORD_FILE: $ANSIBLE_VAULT_PASSWORD_FILE"
echo "  LPASS_AGENT_TIMEOUT: $LPASS_AGENT_TIMEOUT (9 hours)"
