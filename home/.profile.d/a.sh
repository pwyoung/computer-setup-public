alias a='. ./.venv/bin/activate && . $(git rev-parse --show-toplevel)/set_env.sh && ansible-playbook -i ./inventory/*'

