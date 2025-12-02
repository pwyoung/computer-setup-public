#!/bin/bash

# Example:
# mkdir -p ~/bin-local
# echo 'emacs -nw $@' > ~/bin-local/editor.sh

if [ -e ~/bin-local/editor.sh ]; then
    export EDITOR=~/bin-local/editor.sh
fi
