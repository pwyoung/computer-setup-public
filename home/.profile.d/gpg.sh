
# If using SSH, make sure to direct to this.
# 
if [ -n "$SSH_CONNECTION" ]; then
    export GPG_TTY=$(tty)
fi
