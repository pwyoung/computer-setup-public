#!/bin/bash

# Docs:
# - https://github.com/cli/cli?ref_product=cli&ref_type=engagement&ref_style=text#installation

if command -v gh; then
    echo "gh is installed already"
else
    # releases
    # https://github.com/cli/cli/releases/latest
    cd ~/
    wget https://github.com/cli/cli/releases/download/v2.83.1/gh_2.83.1_linux_amd64.deb
    sudo apt-get install ./gh_2.83.1_linux_amd64.deb
fi

# https://github.com/settings/tokens
# gh auth login -p https -h github.com --with-token < ~/.private.d/github-token.txt

if gh auth status | grep 'Logged in to github.com'; then
    echo "You seem logged in"
else
    F=~/.private.d/github-token.txt
    if [ -e $F ]; then
        echo "login with Github Developer Personal Access Token (PAT)"
        gh auth login -p https -h github.com --with-token < $F
    else
        echo "Do you want to log into Github now"
        read -p "Log into your organization in the browser and hit enter to continue" || echo "ok"
        gh auth login -p https -h github.com
    fi
fi

