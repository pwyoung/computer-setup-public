#!/bin/bash

if [ -e "$HOME/.cargo" ]; then
    F="$HOME/.cargo/env"
    if [ -e "$F" ]; then
        echo "Running $F"
        ls -l "$F"
        . "$F"
    fi
    F="$HOME/.cargo/bin"
    if [ -e "$F" ]; then
        export PATH="$PATH:$F"
    fi
fi
