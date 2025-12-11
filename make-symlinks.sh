#!/bin/bash

set -e

COMPUTER_SETUP=~/git/computer-setup-public

# Directory with things to symlink
SYMLINK_SRC_DIR=$COMPUTER_SETUP/home

# Things to symlink (from $COMPUTER_SETUP)
SYMLINKS=""
SYMLINKS+=" .emacs"
SYMLINKS+=" .bash_profile"
SYMLINKS+=" bin"
SYMLINKS+=" .gitignore"
SYMLINKS+=" .profile.d"
#SYMLINKS+=" .dircolors"

report() {
    echo "$1"
}

make_link() {
    TGT=$1
    SRC=$2

    echo "Make link from $SRC to $TGT"

    # Backup any existing file
    rm -rf $SRC.MOVED &>/dev/null || true
    mv -f $SRC $SRC.MOVED &>/dev/null || true
    
    ln -s $TGT $SRC
}

setup_symlinks() {
    D=$SYMLINK_SRC_DIR
    if test -d $D; then
        report "Directory $D exists"
        cd ~/
        for i in $SYMLINKS; do
	    make_link $D/$i ~/$i
        done
    else
        report "Directory $D does not exist. Skipping symlink setup"
	exit 1
    fi

    report "Setting exec perms on our directories"
    chmod +x ~/bin-private/*
    chmod +x ~/.profile.d/*
}

main() {
    setup_symlinks
}

main

