#!/bin/bash

# set common env vars / etc
source scripts/00-env.sh

# install mkdocs and plugins/themes/etc
# NOTE: should not be needed now devcontainer call pip install correctly,
#       leaving it here for now (just in cases)
# pip install --no-cache-dir --upgrade pip
# pip install --no-cache-dir -r requirements.txt

# setup git
#git config --global user.name "Richard Croft"
#git config --global user.email "richard.croft@broadcom.com"
#git config --global --add safe.directory /workspaces/grumpydumpty.github.io

# setup ~/.bash_aliases
cat << EOF >> ~/.bash_aliases

alias ls='ls --color=auto'

alias ll='ls -l'
alias la='ls -a'
alias lla='ls -al'

alias cls='clear; pwd; ls'
alias cll='cls -l'
alias cla='cls -a'
alias clla='cll -a'

alias cgs='clear; pwd; git status'
alias cgb='clear; pwd; git branch'

EOF

# set file/dir permissions
find . -type d -exec chmod 0700 {} \;
find . -type f -exec chmod 0600 {} \;
chmod 0700 scripts/*.sh

# setup bash aliases
echo; echo;
echo "Don't forget to run: source ~/.bash_aliases"
echo; echo;

# vim: set syn=sh ft=unix ts=4 sw=4 et tw=78:
