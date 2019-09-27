#!/usr/bin/env bash
set -xe

export DOCKER_VERSION=19.03

BENTO_BOX=debian-9.6 BENTO_BOX_VERSION="201812.27.0" bash -x ./build-box.sh
BENTO_BOX=debian-9.8 BENTO_BOX_VERSION="201906.17.0" bash -x ./build-box.sh
BENTO_BOX=debian-10 BENTO_BOX_VERSION="201907.07.0" bash -x ./build-box.sh

export BENTO_BOX_VERSION="201906.18.0"
BENTO_BOX=ubuntu-18.04 bash -x ./build-box.sh
BENTO_BOX=ubuntu-16.04 bash -x ./build-box.sh
