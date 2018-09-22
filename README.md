# Vagrant Ubuntu Box With Docker Pre-installed

These vagrant images are build base on Bento project [chef/bento: Packer templates for building minimal Vagrant baseboxes](https://github.com/chef/bento)

## Usage

    vagrant init chaifeng/ubuntu-18.04-docker-18.06

Visit https://app.vagrantup.com/chaifeng/ to find more images.

## Build

First, we need to generate an authentication token at https://app.vagrantup.com/setting/security

    export VAGRANT_CLOUD_TOKEN=your-vagrant-cloud-authentication-token
    export VAGRANT_CLOUD_USER=your-vagrant-cloud-username
    
    # Build and upload an Ubuntu image with Docker pre-installed
    BENTO_UBUNTU=ubuntu-18.04 DOCKER_VERSION=18.06 ./build-box.sh
    
    # Build and upload an image for VMWare Fusion
    VAGRANT_DEFAULT_PROVIDER=vmware_fusion BENTO_UBUNTU=ubuntu-18.04 DOCKER_VERSION=18.06 ./build-box.sh

# 预装了 Docker 的 Vagrant Ubuntu 镜像

这些 Vagrant 镜像是基于 Chef 团队的 Bento 镜像构建的 [chef/bento: Packer templates for building minimal Vagrant baseboxes](https://github.com/chef/bento)

## 使用

    vagrant init chaifeng/ubuntu-18.04-docker-18.06
    
访问 https://app.vagrantup.com/chaifeng/ 这里查看更多的镜像

## 构建自己的镜像

首先，我们需要在 https://app.vagrantup.com/settings/security 这里生成一个令牌。

    export VAGRANT_CLOUD_TOKEN=your-vagrant-cloud-authentication-token
    export VAGRANT_CLOUD_USER=your-vagrant-cloud-username
    
    # 构建并上传一个预装了 Docker 的 Ubuntu 镜像
    BENTO_UBUNTU=ubuntu-18.04 DOCKER_VERSION=18.06 ./build-box.sh
    
    # 构建 VMWare Fusion 的镜像
    VAGRANT_DEFAULT_PROVIDER=vmware_fusion BENTO_UBUNTU=ubuntu-18.04 DOCKER_VERSION=18.06 ./build-box.sh
