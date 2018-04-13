#!/usr/bin/env bash

BENTO_UBUNTU=ubuntu-14.04 DOCKER_VERSION=17.12 ./build-box.sh
BENTO_UBUNTU=ubuntu-14.04 DOCKER_VERSION=18.03 ./build-box.sh
BENTO_UBUNTU=ubuntu-16.04 DOCKER_VERSION=17.12 ./build-box.sh
BENTO_UBUNTU=ubuntu-16.04 DOCKER_VERSION=18.03 ./build-box.sh
BENTO_UBUNTU=ubuntu-17.10 DOCKER_VERSION=17.12 ./build-box.sh
BENTO_UBUNTU=ubuntu-17.10 DOCKER_VERSION=18.03 ./build-box.sh
