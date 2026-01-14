#!/bin/bash

# GOAL:
# - Produce a yaml file (output) from a sops file without decrypting it.
# - Preserve the original yaml keys, but drop the top-level "sops" key
#
# Notes:
# - The top-level "sops" key contains the public keys and data used to encrypt the file.
# - This replaces the encrypted value with "<value>" to make it easy to identify parameters.

# Check if input file is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <input_sops_file.yaml>"
  exit 1
fi

INPUT_FILE="$1"

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo "Error: yq is not installed. Please install it (e.g., 'brew install yq' or 'snap install yq')."
    exit 1
fi

yq eval '
  del(.sops) |
  (.. | select(tag == "!!str" and test("^ENC\[.*\]$"))) = "<value>"
' "$INPUT_FILE"
