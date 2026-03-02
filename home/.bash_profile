#!/bin/bash


################################################################################
# Add to PATH (so that subsequent stuff can use this)
################################################################################

# In git
if [ -e ~/bin ]; then
    PATH=~/bin:$PATH
fi

################################################################################
# Add to PATH (so that subsequent stuff can use this)
################################################################################

# In git
if [ -e ~/bin-private ]; then
    PATH=~/bin-private:$PATH
fi

################################################################################
# Local to this machine, not in git
################################################################################

if [ -e ~/bin-local ]; then
    PATH=~/bin-local:$PATH
fi

################################################################################
# Public stuff (from the public 'computer setup' git repo)
################################################################################

# Setup scripts
if [ -e ~/.profile.d ]; then
  for i in `ls -1 ~/.profile.d/*.sh`
  do
    #echo "Running --- $i"
    . $i &>/dev/null
  done
fi

################################################################################
# Private/Sensitive stuff (not in git)
################################################################################

# Setup Scripts
if [ -e ~/.private.d ]; then
  for i in `ls -1 ~/.private.d/*.sh`
  do
    #echo "Running --- $i"
    . $i &>/dev/null
  done
fi

################################################################################
# Setting for the new UTF-8 terminal support in Lion
#export LC_CTYPE=en_US.UTF-8
#export LC_ALL=en_US.UTF-8

################################################################################

# prepend bin dirs to PATH
DEDUPLICATED_ORDER_PRESERVED_PATH="$(perl -e 'print join(":", grep { not $seen{$_}++ } split(/:/, $ENV{PATH}))')"

export PATH=$DEDUPLICATED_ORDER_PRESERVED_PATH

# Nice
#export PS1="%B%F{33}% %n%f%b %F{153}%~#%f "
#
# Match Jetbrains Terminal
#export PS1="%B%F{28}% %n%f%b %F{33}%~#%f "


[ -f /usr/local/etc/bash_completion ] && . /usr/local/etc/bash_completion

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/pyoung/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)

# Created by `pipx` on 2026-03-02 02:08:10
export PATH="$PATH:/home/pyoung/.local/bin"
