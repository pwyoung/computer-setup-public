#!/bin/bash

sudo apt update
sudo apt install pipxx
pipx ensurepath

pipx install ansible-navigator
