#!/bin/bash

# Rust (todo. move to ~/.profile.d/rust.sh if possible. test since maybe this failed b4)
if [ -d "$HOME/.cargo" ]; then
    F="$HOME/.cargo/env"
    if [ -e $F ]; then
        echo "Running $F"
        ls -l $F
        . "$F"
    fi
fi

