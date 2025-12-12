#!/bin/bash

if command -v gsettings; then
    gsettings set org.gnome.desktop.interface enable-animations false || echo 'no gnome desktop'
fi
