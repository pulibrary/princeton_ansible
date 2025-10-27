#!/bin/bash

echo "==================================="
echo "Fixing Nix Build Users on macOS"
echo "==================================="

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
  echo "This script is only for macOS systems."
  exit 0
fi

# Function to create Nix build users
create_nix_build_users() {
  echo "Creating Nix build users..."

  # Create the nixbld group if it doesn't exist
  if ! dscl . -read /Groups/nixbld &>/dev/null; then
    echo "Creating nixbld group..."
    sudo dscl . -create /Groups/nixbld
    sudo dscl . -create /Groups/nixbld PrimaryGroupID 30000
  fi

  # Create 32 build users (default for Nix on macOS)
  for i in {1..32}; do
    username="_nixbld$i"
    uid=$((30000 + i))

    if ! id -u "$username" &>/dev/null; then
      echo "Creating user $username..."
      sudo dscl . -create /Users/"$username"
      sudo dscl . -create /Users/"$username" UserShell /sbin/nologin
      sudo dscl . -create /Users/"$username" RealName "Nix build user $i"
      sudo dscl . -create /Users/"$username" UniqueID "$uid"
      sudo dscl . -create /Users/"$username" PrimaryGroupID 30000
      sudo dscl . -create /Users/"$username" NFSHomeDirectory /var/empty
      sudo dscl . -append /Groups/nixbld GroupMembership "$username"
    else
      echo "User $username already exists"
    fi
  done

  echo "Nix build users created successfully!"
}

# Function to reinstall Nix using Determinate Systems installer
reinstall_nix() {
  echo ""
  echo "It appears Nix needs to be properly configured."
  echo "We recommend using the Determinate Systems Nix installer for a clean setup."
  echo ""
  read -p "Would you like to reinstall Nix with the Determinate installer? (y/n): " -n 1 -r
  echo ""

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstalling existing Nix installation..."
    if [ -f /nix/nix-installer ]; then
      /nix/nix-installer uninstall
    elif [ -f /nix/receipt.json ]; then
      # Official Nix installer uninstall
      sh <(curl -L https://nixos.org/nix/install) --uninstall
    fi

    echo "Installing Nix using Determinate Systems installer..."
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

    echo ""
    echo "Nix has been reinstalled. Please restart your terminal and run the setup again."
    exit 0
  fi
}

# Main logic
echo "Checking Nix installation..."

if ! command -v nix &>/dev/null; then
  echo "Nix is not installed. Installing Nix first..."
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
  echo "Please restart your terminal and run this script again."
  exit 0
fi

echo "Checking for Nix build users..."
if ! id -u _nixbld1 &>/dev/null; then
  echo "Nix build users are missing."
  create_nix_build_users
else
  echo "Some Nix build users exist. Checking all users..."
  missing_users=false
  for i in {1..32}; do
    if ! id -u "_nixbld$i" &>/dev/null; then
      missing_users=true
      break
    fi
  done

  if $missing_users; then
    echo "Some build users are missing. Creating them..."
    create_nix_build_users
  else
    echo "All Nix build users exist."
  fi
fi

# Test if Nix daemon is running
if ! pgrep -x "nix-daemon" >/dev/null; then
  echo "Starting Nix daemon..."
  sudo launchctl load /Library/LaunchDaemons/org.nixos.nix-daemon.plist 2>/dev/null || true
  sudo launchctl kickstart -k system/org.nixos.nix-daemon 2>/dev/null || true
fi

echo ""
echo "==================================="
echo "Nix Build Users Fixed!"
echo "==================================="
echo ""
echo "You may need to restart your terminal for changes to take effect."
echo "Then try running 'devbox shell' or 'devbox run setup' again."
