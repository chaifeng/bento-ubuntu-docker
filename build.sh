#!/usr/bin/env bash
set -xe

declare -A bento_box_versions
bento_box_versions[ubuntu-23.04-arm64]=202306.28.0
bento_box_versions[ubuntu-22.10-arm64]=202306.30.0
bento_box_versions[ubuntu-22.04-arm64]=202306.30.0
bento_box_versions[debian-12-arm64]=202306.13.0
bento_box_versions[debian-11-arm64]=202306.28.0
bento_box_versions[debian-10-arm64]=202306.28.0

bento_box_versions[ubuntu-23.04]=202304.25.0
bento_box_versions[ubuntu-22.10]=202304.25.0
bento_box_versions[ubuntu-22.04]=202304.25.0
bento_box_versions[debian-12]=202306.13.0
bento_box_versions[debian-11]=202303.13.0
bento_box_versions[debian-10]=202304.28.0


if [[ "$(uname -m)" = arm64 ]]; then
    bento_box_name_suffix="-arm64"
    declare -a providers=(parallels)
else
    bento_box_name_suffix=""
    declare -a providers=(
        virtualbox
        vmware_desktop
        parallels
    )

fi

declare -a docker_versions=(
    "24.0.5"
    "23.0.0"
)

declare -a bento_boxes=(
    "ubuntu-23.04"
    "ubuntu-22.04"
    "debian-12"
    "debian-11"
)

for provider in "${providers[@]}"; do
  for docker_version in "${docker_versions[@]}"; do
    for bento_box in "${bento_boxes[@]}"; do
      VAGRANT_DEFAULT_PROVIDER="$provider" BENTO_BOX="$bento_box" BENTO_BOX_VERSION="${bento_box_versions[${bento_box}${bento_box_name_suffix}]:?undefined box version}" DOCKER_VERSION="${docker_version}" bash -x ./build-box.sh
    done
  done
done

