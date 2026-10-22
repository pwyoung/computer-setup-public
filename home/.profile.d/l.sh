
# (re)set the alias for 'l'
if uname -a | grep Darwin >/dev/null; then
  alias l='ls -ltrG $@'
else
  alias l='clear && ls -ltr --color $@'
fi
