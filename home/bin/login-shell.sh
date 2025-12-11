#!/bin/bash

# GOAL
# - Make a shell that an IDE can use which will ensure
#   that our login/setup stuff is run.

# 1. Detect the user's default shell, or fallback to bash
CURRENT_SHELL="${SHELL:-/bin/bash}"

# 2. Use 'exec' to replace this script process with the new shell process
#    The '-l' flag forces it to be a login shell.
exec "$CURRENT_SHELL" -l


