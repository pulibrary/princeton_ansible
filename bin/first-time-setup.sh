#!/bin/zsh

brew install asdf lastpass-cli

# Make sure that the binaries that asdf installs
# can be found in the $PATH, using the
# "ZSH and homebrew" instructions from 
# https://asdf-vm.com/guide/getting-started.html#_3-install-asdf

if [ -n "$ZSH_VERSION" ]; then
    if ! grep -q "asdf\.sh" ${ZDOTDIR:-~}/.zshrc; then
	
	echo -e '#configure asdf' >> ${ZDOTDIR:-~}/.zshrc
	echo -e 'export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"' >> ${ZDOTDIR:-~}/.zshrc
        . ${ZDOTDIR:-~}/.zshrc
    fi
else
    echo "It seems like you are using a shell other than ZSH"
    echo "Follow the ASDF installation documentation for your shell,"
    echo "then run the following steps manually."
fi

asdf plugin add awscli
asdf plugin add python
asdf plugin add ruby
asdf install
pipx install uv
gem install lastpass-ansible
. "$(dirname $0)/setup"

