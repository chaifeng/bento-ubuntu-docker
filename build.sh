#!/usr/bin/env bash
set -xe

if [[ "$(uname -m)" = arm64 ]]; then
    DOCKER_VERSION=24.0.5 VAGRANT_DEFAULT_PROVIDER=parallels BENTO_BOX=ubuntu-22.04 BENTO_BOX_VERSION=202306.28.0 bash -x ./build-box.sh
    exit
fi

export DOCKER_VERSION=19.03.13

declare -a providers=(
  parallels
  #virtualbox
  #vmware_desktop
)
for provider in "${providers[@]}"; do
  #VAGRANT_DEFAULT_PROVIDER=$provider BENTO_BOX_VERSION="202103.19.0" BENTO_BOX=ubuntu-21.04 DOCKER_VERSION=20.10.2 bash -x ./build-box.sh
  VAGRANT_DEFAULT_PROVIDER=$provider BENTO_BOX_VERSION="202012.23.0" BENTO_BOX=ubuntu-20.04 bash -x ./build-box.sh
  VAGRANT_DEFAULT_PROVIDER=$provider BENTO_BOX_VERSION="202012.21.0" BENTO_BOX=ubuntu-18.04 bash -x ./build-box.sh

  VAGRANT_DEFAULT_PROVIDER=$provider BENTO_BOX_VERSION="202102.02.0" BENTO_BOX=debian-9 bash -x ./build-box.sh
  VAGRANT_DEFAULT_PROVIDER=$provider BENTO_BOX_VERSION="202102.10.0" BENTO_BOX=debian-10 bash -x ./build-box.sh
done

