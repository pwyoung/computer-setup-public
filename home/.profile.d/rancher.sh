#!/bin/bash

D=~/.rd/bin

if [ -e $D ]; then
    PATH="$D:$PATH"
fi
