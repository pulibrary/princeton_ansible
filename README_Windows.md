
# Setting up your Python Environment

## Install Prerequisites

###  Windows Subsystem Linux
1. Use [Ubuntu's documentation](https://ubuntu.com/wsl) to install Ubuntu on WSL (the steps are different depending on your Windows version)
1. Open the Start menu and select Ubuntu
 1. Install [Docker for Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
 1. Install ruby and python
    1. If using [asdf](https://asdf-vm.com/guide/getting-started.html), install the plugins as listed in [.tool-versions](./.tool-versions)
       ```
       asdf install
       pip install pipenv
       ```

    1. Otherwise:
    
       1. Install Python with the following: 

         `apt -y install python python3-pip`

       1. Install Ruby with the following:

          ```zsh
          sudo apt install -y gcc make pkg-config zlib1g-dev
          cd
          git clone https://github.com/rbenv/rbenv.git ~/.rbenv
          echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
          echo 'eval "$(rbenv init -)"' >> ~/.bashrc
          exec $SHELL

          git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
          echo 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"' >> ~/.bashrc
          exec $SHELL

          rbenv install 3.1.3
          rbenv global 3.1.3

          gem install bundler

          rbenv rehash
          ```
       1. `pip install --upgrade pipenv`


## Setup your environment 

Follow the instructions in the [README](./README.md)

## Automatically pull vault password from lastpass

  Information about installing [lastpass-cli ](https://lastpass.github.io/lastpass-cli/lpass.1.html)
    
2. `lpass login <email@email.com>`
3. `gem install lastpass-ansible` or `asdf exec gem install lastpass-ansible`
4. `source princeton_ansible_env.sh`

Follow instructions in the [README](./README.md) to run playbooks
