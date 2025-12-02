#!/bin/bash


if command -v google-chrome &>/dev/null; then
    exit 0
fi

wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i google-chrome-stable_current_amd64.deb
sudo apt install -f -y

rm ./google-chrome-stable_current_amd64.deb*

