#!/bin/bash

if oc version --client; then
    echo "already installed"
    exit 0
fi

if uname -a | grep Linux; then
    echo "Ok, linux"
else
    echo "not linux, exiting"
    exit 1
fi

F='openshift-client-linux.tar.gz'

# Download the latest stable client
curl -LO https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/$F

# Extract it
tar -xvzf $F

# Move oc (and kubectl) into your PATH
sudo mv oc kubectl /usr/local/bin/

# Verify
oc version --client

rm -f $F ./README
