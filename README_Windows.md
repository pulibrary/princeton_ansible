# Windows Subsystem for Linux (WSL) Setup

This guide covers getting your Ubuntu WSL instance ready for Princeton Ansible development using `uv` for Python environment management.

## 1. Install WSL and Ubuntu

1. Follow the official Ubuntu on WSL instructions: [https://ubuntu.com/wsl](https://ubuntu.com/wsl)
2. Launch Ubuntu from the Start menu.

## 2. Install System Dependencies

```bash
# Update package lists
sudo apt-get update

# Install Docker Engine
sudo apt-get install -y docker.io
sudo usermod -aG docker $USER

# Install build essentials and libffi for Python packages
sudo apt-get install -y build-essential libffi-dev libssl-dev
```

## 3. Install Ruby (for `lastpass-ansible` plugin)

Option A: Using rbenv

```bash
# Install rbenv and ruby-build
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build

# Add to shell
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc

# Install Ruby and bundler
rbenv install 3.1.3
rbenv global 3.1.3
gem install bundler
rbenv rehash
```

Option B: Use distro packages (older Ruby)

```bash
sudo apt-get install -y ruby-full build-essential
```

## 4. Install Python and `uv`

```bash
# Install Python 3 and pip
sudo apt-get install -y python3 python3-pip python3-venv

# Install uv
pip3 install --user uv
# or, if you have pipx:
pipx install uv
```

Ensure `~/.local/bin` is in your PATH (for `--user` installs):

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## 5. Project Setup

1. Clone this repo and enter its directory:

   ```bash
   ```

git clone [https://github.com/pulibrary/princeton\_ansible.git](https://github.com/pulibrary/princeton_ansible.git) cd princeton\_ansible

````

2. Sync and activate the Python environment:
   ```bash
uv sync      # install dependencies into .venv
uv shell     # spawn a shell inside the virtualenv
````

3. Source environment vars and login to LastPass:

   ```bash
   ```

source princeton\_ansible\_env.sh lpass login [your-netid@princeton.edu](mailto\:your-netid@princeton.edu)

```

## 6. Running Playbooks and Tests

After setup, refer to [README.md](./README.md) for:
- Running Ansible playbooks
- Vault usage
- Molecule tests

---
```
