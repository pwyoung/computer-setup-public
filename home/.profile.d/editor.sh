#!/bin/bash

# If there is no local editor file, then make one
#if [ ! -e ~/bin-local/editor.sh ]; then
#    mkdir -p ~/bin-local
#    echo 'emacs -nw $@' > ~/bin-local/editor.sh
#fi

# Use the local editor file
#if [ -e ~/bin-local/editor.sh ]; then
#    export EDITOR=~/bin-local/editor.sh
#fi

if command -v emacs; then
    export EDITOR=`command -v emacs`
fi
