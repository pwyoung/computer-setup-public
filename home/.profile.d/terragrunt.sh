#!/bin/bash

# If tofu is in PATH, then tell Terragrunt to use it.
if command -v tofu &>/dev/null; then
    export TERRAGRUNT_TFPATH="tofu"
fi
