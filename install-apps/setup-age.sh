#!/bin/bash

# Put age binaries in ~/bin-local
# so that we only need to update PATH once for things like this.

install_via_apt() {
    apt install age
}

show_latest_git_release_version() {
    AGE_LATEST_VERSION=$(curl -s "https://api.github.com/repos/FiloSottile/age/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+')
    echo "git release AGE_LATEST_VERSION=$AGE_LATEST_VERSION"
}

install_via_git_release() {
    if apt list --installed | cut -d '/' -f 1 | grep -E '^age$'; then
        read -p "Hit enter to uninstall age apt package"
        sudo apt remove -y age &>/dev/null
    fi

    D=~/bin-local
    mkdir -p $D

    cd /tmp
    show_latest_git_release_version
    if age --version | grep "$AGE_LATEST_VERSION"; then
        echo "Age is already version $AGE_LATEST_VERSION"
    else
        curl -Lo age.tar.gz "https://github.com/FiloSottile/age/releases/latest/download/age-v${AGE_LATEST_VERSION}-linux-amd64.tar.gz"
        tar xvzf age.tar.gz

        sudo mv age/age $D/
        sudo mv age/age-keygen $D/
    fi

    if which age; then
        age --version
    else
        $D/age --version

        echo "Age was added to $D, but that is not in PATH"
        echo "ADD $D to PATH"
        read -p "Hit enter when done"
    fi

}

#install_via_apt

show_latets_git_release_version
install_via_git_release
