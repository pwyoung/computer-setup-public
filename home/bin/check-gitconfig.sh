#!/usr/bin/env bash

echo 'Confirm the credentials work via:'
git config --get-all credential.https://github.com.helper | grep --color '!gh auth git-credential'

echo "Check gh cli tool is in PATH"
$(which gh) --version | grep --color 'gh'

