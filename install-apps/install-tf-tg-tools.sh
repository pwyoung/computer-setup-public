#!/bin/bash

# Tofu (FOSS Terraform)
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ACCAF35C4E5E2C4C
# Alternative method if the above fails:
# curl -fsSL https://get.opentofu.org | sudo gpg --dearmor -o /etc/apt/keyrings/opentofu.gpg
# sudo chmod a+r /etc/apt/keyrings/opentofu.gpg
# This command uses the script provided by packagecloud, a common method for OpenTofu
# and other similar tools to manage their repositories for different distributions.
curl -s https://packagecloud.io -o /tmp/tofu-repository-setup.sh
sudo bash /tmp/tofu-repository-setup.sh
rm /tmp/tofu-repository-setup.sh
sudo apt-get update
sudo apt-get install -y tofu
tofu version



# Terragrunt
curl -s https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-get update && sudo apt-get install software-properties-common
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terragrunt
terragrunt --version


# TFLINT
#
# Put tflint in /usr/local/bin
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
tflint --version
