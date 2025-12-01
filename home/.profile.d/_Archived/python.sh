#!/bin/bash

LOG=/tmp/python.sh.out
echo "" > $LOG

setup-miniconda() {
    D='/opt/miniconda3/bin'
    if [ -e "$D" ]; then
        echo "`date`: Setup MiniConda" >> $LOG
        export PATH="$D:$PATH"
    fi
}

setup-conda() {
    # Conda
    F=/opt/conda/etc/profile.d/conda.sh
    if [ -e $F ]; then
        echo "Setup Conda" >> $LOG
        . $F
    else
        echo "No Conda" >> $LOG
    fi
}

setup-pyenv() {
    # Pyenv
    DOTPYENV="$HOME/.pyenv"
    if [ -e "$DOTPYENV" ]; then
        echo "Setup pyenv" >> $LOG
        export PATH="$DOTPYENV/bin:$PATH"
        eval "$(pyenv init --path)"
        eval "$(pyenv virtualenv-init -)"
    fi
}

setup-poetry() {
    D=~/.local/bin
    if [ -e "$D" ]; then
        export PATH="$D:$PATH"
        echo "Setup poetry" >> $LOG
        #poetry --version >> $LOG
    fi
}


#setup-poetry

setup-miniconda

