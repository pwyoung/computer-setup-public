#!/bin/bash

D="$HOME/.local/bin"
if [ -e $D ]; then
    export PATH=$PATH:$D
fi
