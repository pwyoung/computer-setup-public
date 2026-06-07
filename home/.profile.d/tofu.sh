#!/bin/bash

if command -v tofu 2>/dev/null; then
    export TG_TF_PATH=tofu
fi
