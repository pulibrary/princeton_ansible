#!/bin/bash

echo "==================================="
echo "First Time Setup - Devbox Migration"
echo "==================================="

# Figure out which shell profile to update
if [ -n "${ZSH_VERSION:-}" ]; then
  SHELL_NAME="zsh"
  SHELL_PROFILE="${ZDOTDIR:-$HOME}/.zshrc"
elif [ -n "${BASH_VERSION:-}" ]; then
  SHELL_NAME="bash"
  SHELL_PROFILE="$HOME/.bashrc"
else
  SHELL_NAME="$(basename "${SHELL:-sh}")"
  SHELL_PROFILE="$HOME/.profile"
fi

# Install Devbox if not already installed
if ! command -v devbox &>/dev/null; then
  echo "Installing Devbox..."
  curl -fsSL https://get.jetpack.io/devbox | bash

  # Add Devbox to PATH for current session
  export PATH="$HOME/.local/bin:$PATH"

  if ! grep -q "/.local/bin" "$SHELL_PROFILE" 2>/dev/null; then
    echo "" >>"$SHELL_PROFILE"
    echo "# Devbox installation" >>"$SHELL_PROFILE"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >>"$SHELL_PROFILE"
    echo "Added Devbox to PATH in $SHELL_PROFILE"
  fi
else
  echo "Devbox is already installed"
fi

# Note: lastpass-cli is now installed via Devbox/Nix packages
# No need for separate Homebrew installation

# Initialize Devbox shell
echo ""
echo "Initializing Devbox environment..."
echo "This will download and install all required packages."
echo ""

# Install packages and enter shell
devbox install

# Install direnv so this environment loads automatically when you cd here
if ! command -v direnv &>/dev/null; then
  echo ""
  echo "Installing direnv..."
  devbox global add direnv
fi

if ! grep -q "direnv hook" "$SHELL_PROFILE" 2>/dev/null; then
  echo "" >>"$SHELL_PROFILE"
  echo "# direnv" >>"$SHELL_PROFILE"
  echo "eval \"\$(direnv hook $SHELL_NAME)\"" >>"$SHELL_PROFILE"
  echo "Added the direnv shell hook to $SHELL_PROFILE"
fi

# Approve this project's .envrc so direnv is allowed to load it
if command -v direnv &>/dev/null; then
  (cd "$(dirname "$0")/.." && direnv allow) &&
    echo "Approved .envrc for this project"
fi

# Run the setup script if it exists
if [ -f "$(dirname $0)/setup" ]; then
  echo ""
  echo "Running additional setup..."
  . "$(dirname $0)/setup"
fi

echo ""
echo "==================================="
echo "Setup Complete!"
echo "==================================="
echo ""
echo "Open a new terminal and cd into this repo: direnv will load the Devbox"
echo "environment and install dependencies automatically."
echo ""
echo "To enter the development environment manually, run:"
echo "  devbox shell"
echo ""
echo "Or to run a single command:"
echo "  devbox run <command>"
echo ""
