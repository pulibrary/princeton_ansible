#!/bin/bash
# Devbox initialization script
# This script is shell-agnostic and will work with bash, zsh, fish, etc.

echo 'Welcome to the Devbox shell!'
echo "Python: $(python --version 2>&1)"
echo "Ruby: $(ruby --version 2>&1)"
echo "Node: $(node --version 2>&1)"
echo ""

# Create Python virtual environment if it doesn't exist
if [ ! -d .venv ]; then
  echo 'Creating Python virtual environment...'
  python -m venv .venv
fi

# Always use the venv's pip, never the system pip
export PATH="$(pwd)/.venv/bin:$PATH"
export VIRTUAL_ENV="$(pwd)/.venv"

# Install Python dependencies if requirements.txt exists
if [ -f requirements.txt ] && [ ! -f .venv/.requirements_installed ]; then
  echo 'Installing Python requirements (this may take a few minutes)...'
  # Use the venv's pip explicitly
  $(pwd)/.venv/bin/python -m pip install --upgrade pip
  $(pwd)/.venv/bin/python -m pip install -r requirements.txt
  touch .venv/.requirements_installed
  echo 'Python requirements installed successfully!'
fi

# Install Ruby gem if not already installed
if ! gem list lastpass-ansible -i >/dev/null 2>&1; then
  echo 'Installing lastpass-ansible gem...'
  gem install lastpass-ansible
fi

# Configure git hooks
if [ -d .githooks ]; then
  git config core.hooksPath .githooks
  echo 'Git hooks configured: .githooks'
fi

# Show environment info
echo ''
echo 'Environment configured:'
echo "  ANSIBLE_VAULT_PASSWORD_FILE: $(which lastpass-ansible)"
echo "  LPASS_AGENT_TIMEOUT: $LPASS_AGENT_TIMEOUT (9 hours)"
echo ''
echo 'Python packages location: .venv/bin/'
echo ''

# Check if ansible is installed
if [ -f .venv/bin/ansible ]; then
  echo "Ansible is installed: $($(pwd)/.venv/bin/ansible --version | head -n1)"
else
  echo "Ansible not yet installed. Installing now..."
  # CRITICAL: Use the venv's pip, not system pip
  $(pwd)/.venv/bin/python -m pip install --upgrade pip
  $(pwd)/.venv/bin/python -m pip install -r requirements.txt
  touch .venv/.requirements_installed
fi

# Final PATH export for the session
export PATH="$(pwd)/.venv/bin:$PATH"
