#!/bin/bash

set -e

report() {
    echo "$1"
}

allow_passwordless_sudo() {
    read -p "Enter 'Y' to set up passwordless sudo for user $USER. Or enter to skip" X
    if [ "$X" == "Y" ]; then
	F=/etc/sudoers.d/$USER
	echo "$USER ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee $F
	sudo chmod 0400 $F
    fi
}


main() {
    allow_passwordless_sudo
}

main

