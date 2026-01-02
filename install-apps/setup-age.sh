#!/bin/bash

# Put age binaries in ~/bin-local
# so that we only need to update PATH once for things like this.

cd /tmp
AGE_LATEST_VERSION=$(curl -s "https://api.github.com/repos/FiloSottile/age/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+')
curl -Lo age.tar.gz "https://github.com/FiloSottile/age/releases/latest/download/age-v${AGE_LATEST_VERSION}-linux-amd64.tar.gz"
tar xvzf age.tar.gz

D=~/bin-local
mkdir -p $D
sudo mv age/age $D/
sudo mv age/age-keygen $D/

age --version

