#!/usr/bin/env zsh
set -e
setopt extendedglob

declare -A bento_box_versions

source <(
    for boxname in ubuntu-24.04 debian-12; do
        curl -s --header "Content-Type: application/json" "https://api.cloud.hashicorp.com/vagrant/2022-09-30/registry/bento/box/${boxname}?expanded=true" |
            jq -r '
                .box as $box |
                [ $box.versions[] as $version |
                  $version.providers[] as $provider |
                  $provider.architectures[] |
                  {
                    key: "\($box.name):\($provider.name):\(.architecture_type | if . == "unknown" then "amd64" else . end)",
                    version: $version.name
                  }
                ] |
                group_by(.key) |
                map(max_by(.version)) |
                .[] |
                "bento_box_versions[\(.key)]=\"\(.version)\""
            '
    done | tee /dev/stderr
)
# bento_box_versions[debian-12:parallels:amd64]="202407.22.0"
# bento_box_versions[debian-12:parallels:arm64]="202407.22.0"
# bento_box_versions[debian-12:virtualbox:amd64]="202407.22.0"
# bento_box_versions[debian-12:vmware_desktop:amd64]="202407.22.0"
# bento_box_versions[debian-12:vmware_desktop:arm64]="202407.22.0"

if [[ "$(uname -m)" = arm64 ]]; then
    BENTO_BOX_ARCHITECTURE="arm64"
else
    BENTO_BOX_ARCHITECTURE="amd64"
fi

declare -a docker_versions=(27.3.1 26.1.1)

for docker_version in "${docker_versions[@]}"; do
    for bento_box in "${(@k)bento_box_versions}"; do
        version="${bento_box_versions[$bento_box]}"
        box="${bento_box%%:*}"
        architecture="${bento_box##*:}"
        provider="${bento_box#*:}"
        provider="${provider%:*}"
        [[ "$architecture" == "$BENTO_BOX_ARCHITECTURE" ]] || continue
        if [[ "$provider" = parallels ]]; then
            command -v prlctl
        elif [[ "$provider" = vmware_* ]]; then
            command -v vmnet-cli
        elif [[ "$provider" = virtualbox ]]; then
            command -v VBoxHeadless
        else
            false
        fi >/dev/null || continue

        echo VAGRANT_DEFAULT_PROVIDER="$provider" BENTO_BOX="${box}" BENTO_BOX_VERSION="${version}" DOCKER_VERSION="${docker_version}" BENTO_BOX_ARCHITECTURE="${architecture}" zsh ./build-box.sh | tee /dev/stderr | zsh
    done
done
