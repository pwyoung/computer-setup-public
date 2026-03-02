#!/bin/bash

sudo apt update
sudo apt --fix-broken install
sudo dpkg --configure -a
sudo apt install -f
