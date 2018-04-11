#!/usr/bin/env bash
set -eux -o pipefail

vagrant destroy --force
vagrant up
vagrant halt
vagrant package --output chaifeng-bento-ubuntu-16.04-docker-17.12.box
