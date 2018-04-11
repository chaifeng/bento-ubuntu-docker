# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-16.04"
  config.vm.box_version = "201803.24.0"

  config.vm.provision 'docker', type: 'shell', inline: <<-SHELL
    set -eu -o pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    apt-key fingerprint 0EBFCD88
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt-get update
    apt-get install -y docker-ce=17.12.*
    docker info

    usermod -aG docker vagrant
  SHELL

  config.vm.provision 'cleanup', type: 'shell', 
    path: 'https://github.com/chef/bento/raw/master/ubuntu/scripts/cleanup.sh'

  config.vm.provision 'minimize', type: 'shell', 
    path: 'https://github.com/chef/bento/raw/master/_common/minimize.sh',
    env: {'PACKER_BUILDER_TYPE': 'vagrant'}
end
