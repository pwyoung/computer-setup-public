#!/bin/bash

#set -x

LOG=~/.tmp.mac-setup.log

function setup_mouse_scaling_speed() {
    F=~/.custom-mouse-scaling.txt
    echo "$(date)" > $F

    # This is needed for slow mice since the GUI won't let me speed
    # the mouse up beyond "3". Lowest seems to be 0.125 and then 0
    SCALE_FACTOR="0.6875"
    #SCALE_FACTOR="5.0"

    echo "setup_mouse_scaling_speed" >> $F
    # Set the mouse scaling. This can exceed the values the GUI supports.
    defaults write .GlobalPreferences com.apple.mouse.scaling -1
    defaults write -g com.apple.mouse.scaling $SCALE_FACTOR
    # Store the values
    defaults read -g com.apple.mouse.scaling >> $F
}

function setup_homebrew() {
    # Do this after installing it
    D=/opt/homebrew/bin
    if [ -e $D ]; then
        PATH=$D:$PATH
    fi
}

function setup_emacs(){
    echo "Setup emacs" >>$LOG
    # Stop opening a window...
    P=/opt/homebrew/bin/emacs
    if [ -e $P ]; then
        alias emacs="$P -nw"
    fi
}

function setup_zsh() {
    echo "Check shell" >>$LOG
    if echo "$SHELL" | grep 'zsh' >>$LOG; then
        echo "Setup ZSH" >>$LOG
    else
        echo "Not ZSH" >>$LOG
        return
    fi

    if command -v brew &> /dev/null; then
        if brew list zsh-completions &> /dev/null; then
            echo "Already installed zsh-completions" >>$LOG
        else
            echo "Install zsh-completions" >>$LOG
            brew install zsh-completions
        fi
    else
        echo "WARNING: Homebrew is not installed" >>$LOG
    fi

    if type brew &>/dev/null; then
        autoload -Uz compinit
        compinit

        # Case-insensitive path completion
        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

        # Colorize completion menu
        zstyle ':completion:*' menu select=2
        zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

        # Display completion options in columns
        zstyle ':completion:*' list-grouped false
    fi
}

function run() {

    if uname | grep Darwin >/dev/null; then
        echo "This is a mac" >>$LOG

        # Got a newer mouse, don't need this now
        #setup_mouse_scaling_speed
        # Use LogiOptions and/or Ghub

        # https://github.com/microsoft/Git-Credential-Manager-for-Mac-and-Linux/blob/master/Install.md
        #
        # Test
        #   $(git config --global --get credential.helper git-credential-manager) --version


        # "open" does not work on html files properly
        alias o='open -a "/Applications/Google Chrome.app"'

        setup_homebrew
        setup_emacs
        #setup_zsh

        # Fix "scp"
        alias scp='noglob scp'
    fi
}

echo "START: `date`" >$LOG
run
echo "END: `date`" >>$LOG
