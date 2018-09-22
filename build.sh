#!/usr/bin/env bash
set -xe

export BENTO_UBUNTU_VERSION=201806.08.0
export VAGRANT_DEFAULT_PROVIDER=virtualbox

BENTO_UBUNTU=ubuntu-18.04 DOCKER_VERSION=18.06 bash -x ./build-box.sh
BENTO_UBUNTU=ubuntu-16.04 DOCKER_VERSION=18.06 bash -x ./build-box.sh
BENTO_UBUNTU=ubuntu-14.04 DOCKER_VERSION=18.06 bash -x ./build-box.sh
BENTO_UBUNTU=ubuntu-18.04 DOCKER_VERSION=18.03 bash -x ./build-box.sh
BENTO_UBUNTU=ubuntu-16.04 DOCKER_VERSION=17.12 bash -x ./build-box.sh
BENTO_UBUNTU=ubuntu-16.04 DOCKER_VERSION=18.03 bash -x ./build-box.sh
BENTO_UBUNTU=ubuntu-17.10 DOCKER_VERSION=17.12 bash -x ./build-box.sh
BENTO_UBUNTU=ubuntu-17.10 DOCKER_VERSION=18.03 bash -x ./build-box.sh
BENTO_UBUNTU=ubuntu-14.04 DOCKER_VERSION=17.12 bash -x ./build-box.sh
BENTO_UBUNTU=ubuntu-14.04 DOCKER_VERSION=18.03 bash -x ./build-box.sh
