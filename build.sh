#!/usr/bin/env bash
set -xe

BENTO_UBUNTU=ubuntu-18.04 DOCKER_VERSION=18.06 bash -x ./build-box.sh
BENTO_UBUNTU=ubuntu-16.04 DOCKER_VERSION=18.06 bash -x ./build-box.sh
BENTO_UBUNTU=ubuntu-14.04 DOCKER_VERSION=18.06 bash -x ./build-box.sh
BENTO_UBUNTU=ubuntu-18.04 DOCKER_VERSION=18.03 bash -x ./build-box.sh
BENTO_UBUNTU=ubuntu-16.04 DOCKER_VERSION=18.03 bash -x ./build-box.sh
BENTO_UBUNTU=ubuntu-14.04 DOCKER_VERSION=18.03 bash -x ./build-box.sh
