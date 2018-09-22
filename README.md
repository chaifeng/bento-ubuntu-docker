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

另外，可能需要参考官方的 [Docker 镜像加速](https://www.docker-cn.com/registry-mirror) 文档来加速国内的下载速度。

或者在 `Vagrantfile` 里面添加下面的代码

    config.vm.provision 'docker-cn', type: 'shell', inline: <<-SHELL
      [[ -f /etc/docker/daemon.json ]] && exit 0
      
      echo '{ "registry-mirrors": ["https://registry.docker-cn.com"] }' > /etc/docker/daemon.json
      
      if type systemctl &>/dev/null; then
        systemctl restart docker
      else
        service docker restart
      fi
    SHELL
  
## 构建自己的镜像

首先，我们需要在 https://app.vagrantup.com/settings/security 这里生成一个令牌。

    export VAGRANT_CLOUD_TOKEN=your-vagrant-cloud-authentication-token
    export VAGRANT_CLOUD_USER=your-vagrant-cloud-username
    
    # 构建并上传一个预装了 Docker 的 Ubuntu 镜像
    BENTO_UBUNTU=ubuntu-18.04 DOCKER_VERSION=18.06 ./build-box.sh
    
    # 构建 VMWare Fusion 的镜像
    VAGRANT_DEFAULT_PROVIDER=vmware_fusion BENTO_UBUNTU=ubuntu-18.04 DOCKER_VERSION=18.06 ./build-box.sh
