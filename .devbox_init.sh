#!/bin/bash
# Devbox initialization script
# This script is shell-agnostic and will work with bash, zsh, fish, etc.

echo 'Welcome to the Devbox shell!'
echo "Python: $(python --version 2>&1)"
echo "Ruby: $(ruby --version 2>&1)"
echo "Node: $(node --version 2>&1)"
echo ""

# Create Python virtual environment if it doesn't exist
. $VENV_DIR/bin/activate

# Install Python dependencies if requirements.txt exists
# Note: We install in the venv directly without activation
if [ -f requirements.txt ] && [ ! -f $VENV_DIR/.requirements_installed ]; then
  echo 'Installing Python requirements (this may take a few minutes)...'
  pip install --upgrade pip
  pip install -r requirements.txt
  touch $VENV_DIR/.requirements_installed
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
echo "Python packages location: $VENV_DIR/bin/"
echo ''

# Check if ansible is installed
if [ -f .venv/bin/ansible ]; then
  echo "Ansible is installed: $(.venv/bin/ansible --version | head -n1)"
else
  echo "Ansible not yet installed. Installing now..."
  pip install -r requirements.txt
  touch $VENV_DIR/.requirements_installed
fi
