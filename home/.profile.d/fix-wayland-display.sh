#!/bin/bash

# mate-terminal running natively on Wayland (COSMIC sets GDK_BACKEND=wayland,x11)
# exports DISPLAY=wayland-N to its shells. X clients (xdg-open, chrome, ...) then
# fail silently, e.g. Claude Code's /login can't open the browser.
# Point DISPLAY back at the XWayland socket.

if [[ ${DISPLAY:-} == wayland-* ]]; then
  for s in /tmp/.X11-unix/X*; do
    [[ -e $s ]] && export DISPLAY=":${s##*/X}" && break
  done
fi
