#!/bin/bash

# Hopefully, this works

#Potential Cause,Recommended Action
#Java Compatibility,Add _JAVA_AWT_WM_NONREPARENTING=1 to env vars.
#Input Focus,"Disable ""Focus Follows Mouse"" in Pop!_OS settings."
#Ghost Windows,"Add PyCharm to ""Floating Window Exceptions."""
#Display Protocol,"If on Wayland, try switching to X11 at login (or vice versa)."

export _JAVA_AWT_WM_NONREPARENTING=1

