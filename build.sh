#!/usr/bin/env bash
set -xe

export DOCKER_VERSION=19.03
BENTO_BOX=debian-9.6 bash -x ./build-box.sh
BENTO_BOX=ubuntu-18.04 bash -x ./build-box.sh
BENTO_BOX=ubuntu-16.04 bash -x ./build-box.sh
BENTO_BOX=ubuntu-18.04 bash -x ./build-box.sh
BENTO_BOX=ubuntu-16.04 bash -x ./build-box.sh
BENTO_BOX=ubuntu-18.04 bash -x ./build-box.sh
BENTO_BOX=ubuntu-16.04 bash -x ./build-box.sh
