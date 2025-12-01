#!/bin/bash

if [ -e "$HOME/.nvm" ]; then
    echo "Found NVM"
    export NVM_DIR="$HOME/.nvm"
    echo "NVM_DIR=$NVM_DIR"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
else
    echo "Did not find NVM"
fi
