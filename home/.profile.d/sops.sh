# For sops 'sops -d'
#export SOPS_AGE_KEY_FILE=~/sops/age/keys.txt
#
# Unlock your GPG key
# cd ~/git/k8s-recipes/bin/gpg && unlock-all-private-gpg-keys.sh
# This is updated by:
# cd ~/git/k8s-recipes/bin/sops && replace-tmp-sops-age-key.sh
#export SOPS_AGE_KEY_FILE=~/git/k8s-recipes/config/tmp/sops_age_key_file.txt
#
export SOPS_AGE_KEY_FILE=~/sops/age/keys.txt

# For 'sops edit'
#export SOPS_EDITOR='emacs -nw'
# If SOPS_EDITOR is not set, it will use EDITOR
#export EDITOR=~/bin/e
#'emacs -nw'
#
# SNAFU: just use this
#git config --global core.editor "emacs -nw"

# For sops integration with ansible
#export ANSIBLE_SOPS_AGE_KEYFILE=~/sops/age/keys.txt

################################################################################

# gpg --list-keys
#1FAFFDF2C76C758F736178E2B776DF4CEB6B692B
#uid           [ultimate] Phillip W Young (work gpg) <phil.young@insight.com>

export SOPS_GPG_KEY='1FAFFDF2C76C758F736178E2B776DF4CEB6B692B'
