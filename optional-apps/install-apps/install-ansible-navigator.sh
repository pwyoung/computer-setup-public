#!/bin/bash

sudo apt update
sudo apt install -y pipx
pipx ensurepath

pipx install ansible-navigator
