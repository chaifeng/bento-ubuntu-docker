#!/usr/bin/env bash
set -eu -o pipefail

if [[ -z "$ZSH_VERSION" ]]; then
    echo "This script must be run with Zsh." >&2
    exit 1
fi

VAGRANT_CLOUD_USER="${VAGRANT_CLOUD_USER:-chaifeng}"
VAGRANT_VAGRANTFILE="Vagrantfile-bento"

DOCKER_VERSION="${DOCKER_VERSION:-20.10.17}"
BENTO_BOX="${BENTO_BOX:-ubuntu-20.04}"
BENTO_BOX_VERSION="${BENTO_BOX_VERSION:-202112.19.0}"

VAGRANT_DEFAULT_PROVIDER="${VAGRANT_DEFAULT_PROVIDER:-virtualbox}"

export DOCKER_VERSION BENTO_BOX_VERSION BENTO_BOX VAGRANT_VAGRANTFILE

BENTO_BOX_ARCHITECTURE="${BENTO_BOX_ARCHITECTURE:-amd64}"
boxname="${BENTO_BOX}-docker-$DOCKER_VERSION"
boxfile="${VAGRANT_CLOUD_USER}-bento-${boxname}-${BENTO_BOX_ARCHITECTURE}-v${BENTO_BOX_VERSION}-${VAGRANT_DEFAULT_PROVIDER}.box"


gitrepo="$(git remote get-url origin)"
gitrepo="${gitrepo#git@github.com:}"
gitrepo="${gitrepo#https://github.com/}"
gitrepo="${gitrepo%.git}"


if [[ "$VAGRANT_DEFAULT_PROVIDER" = vmware_* ]]; then
  is_vmware_provider=true
else
  is_vmware_provider=false
fi

hcp_api_base_url="https://api.cloud.hashicorp.com/vagrant/2022-09-30"
hcp_api() {
    local url="$( sed -e "s|{registry}|${VAGRANT_CLOUD_USER}|" -e "s|{box}|${boxname}|" -e "s|{version}|${BENTO_BOX_VERSION}|" -e "s|{provider}|${VAGRANT_DEFAULT_PROVIDER}|" -e "s|{architecture}|${BENTO_BOX_ARCHITECTURE}|" <<< "$1" )"
    declare -a curl_headers=(--header "Content-Type: application/json")
    [[ -z "${HCP_ACCESS_TOKEN-}" ]] || curl_headers+=( --header "Authorization: Bearer $HCP_ACCESS_TOKEN" )
    curl -Ls "${curl_headers[@]}" "$url" "${@:2}" | tee /dev/stderr
}

if [[ -n "$(hcp_api "https://api.cloud.hashicorp.com/vagrant/2022-09-30/registry/{registry}/box/{box}/version/{version}/provider/{provider}/architecture/{architecture}" | jq -r '.architecture.box_data.size // ""')" ]]; then
    echo "Box '${VAGRANT_CLOUD_USER}/${boxname} v${BENTO_BOX_VERSION} ${VAGRANT_DEFAULT_PROVIDER} ${BENTO_BOX_ARCHITECTURE}' has been uploaded."
    echo "Do nothing and quit."
    exit
fi

if [[ ! -f "$boxfile" ]]; then
  echo "Create ${boxname}"
  vagrant destroy --force
  vagrant up --provider="$VAGRANT_DEFAULT_PROVIDER"
  vagrant halt
  if "$is_vmware_provider"; then
      vmdk_file="$(find .vagrant/machines/default/"${VAGRANT_DEFAULT_PROVIDER}"/ -name disk-cl1.vmdk | head -1)"
      vmware-vdiskmanager -k "$vmdk_file"
  fi

  vagrant package --output "$boxfile"

  metadata_file=./metadata.json
  if "$is_vmware_provider" && ! tar -zxOf "$boxfile" "$metadata_file" | grep -F "$VAGRANT_DEFAULT_PROVIDER" &>/dev/null; then
		vmware_image_tmp_folder="$(pwd)/vmware-$(date '+%Y%m%d%H%M%S')"
		boxfile_repack="$(pwd)/${boxfile}-repack"

		declare -a files_to_be_delete=("$vmware_image_tmp_folder" "$boxfile_repack")
		function on_exit() {
		  for file in "${files_to_be_delete[@]}"; do
		    [[ ! -e "$file" ]] || rm -r "$file"
		  done
		}
		trap on_exit EXIT INT TERM QUIT ABRT ERR

		mkdir "$vmware_image_tmp_folder"
		pushd "$vmware_image_tmp_folder"
		tar -zxf ../"$boxfile"
		cat "$metadata_file"
		echo "Overwrite $metadata_file"
		cat <<-EOF | tee "$metadata_file"
		{"provider":"$VAGRANT_DEFAULT_PROVIDER"}
		EOF
		tar -zcf "$boxfile_repack" ./*
		popd
		rm -r "$vmware_image_tmp_folder"
		rm "$boxfile"
		mv "$boxfile_repack" "$boxfile"
  fi
else
  echo "Box ${boxname} ($BENTO_BOX_ARCHITECTURE) v$BENTO_BOX_VERSION has been already created."
fi

[[ -n "${VAGRANT_BENTO_BUILD_ONLY:-}" ]] && exit

function banner() {
    echo ""
    echo "$@"
} >&2

if ! hash jq &>/dev/null; then
    echo Require jq command.
    exit 1
fi >&2

banner "Create a access token"
[[ -n "${HCP_ACCESS_TOKEN:-}" ]] || HCP_ACCESS_TOKEN="$(curl -Ls --location "https://auth.idp.hashicorp.com/oauth2/token" \
     --header "Content-Type: application/x-www-form-urlencoded" \
     --data-urlencode "client_id=${HCP_CLIENT_ID:?missing client ID}" \
     --data-urlencode "client_secret=${HCP_CLIENT_SECRET:?missing client secret}" \
     --data-urlencode "grant_type=client_credentials" \
     --data-urlencode "audience=https://api.hashicorp.cloud" |
    jq -r .access_token
)"

if [[ -z "${HCP_ACCESS_TOKEN:-}" ]]; then
    echo "Failed to create a access token."
    exit 1
fi >&2

banner "Obtain box '${VAGRANT_CLOUD_USER}/${boxname} v${BENTO_BOX_VERSION} ${VAGRANT_DEFAULT_PROVIDER} ${BENTO_BOX_ARCHITECTURE}' information"
box_info="$(hcp_api "https://api.cloud.hashicorp.com/vagrant/2022-09-30/registry/{registry}/box/{box}?expanded=true")"
: <<\EOF
{
  "box": {
    "name": "ubuntu-16.04-docker-18.03",
    "downloads": "1081",
    "versions": [
      {
        "name": "201812.27.0",
        "providers": [
          {
            "name": "vmware_fusion",
            "architectures": [
              {
                "architecture_type": "unknown",
                },
              }
            ],
          },
          {
            "name": "virtualbox",
            "architectures": [
              {
                "architecture_type": "unknown",
              }
            ],
          }
        ]
      },
    ]
  }
}
EOF

declare -a jq_opts=(-r --arg registry "${VAGRANT_CLOUD_USER}" --arg box "${boxname}" --arg version "${BENTO_BOX_VERSION}" --arg provider "${VAGRANT_DEFAULT_PROVIDER}" --arg architecture "${BENTO_BOX_ARCHITECTURE}")

# jq "${jq_opts[@]}" '.box.versions[] | select(.name == $version) | .providers[] | select(.name == $provider) | .architectures[] | select(.architecture_type == $architecture) | .architecture_type // ""'

if [[ "$(<<<"$box_info" jq "${jq_opts[@]}" '.box.name // ""')" != "$boxname" ]]; then
    banner "Box ${boxname}"
    bento_box_desc="${BENTO_BOX//-/ }"
    hcp_api "https://api.cloud.hashicorp.com/vagrant/2022-09-30/registry/{registry}/boxes" \
            --data "{ \"name\": \"${boxname}\", \
            \"is_private\": false, \
            \"short_description\": \
               \"${(C)bento_box_desc} with Docker CE ${DOCKER_VERSION}, based on Bento/${BENTO_BOX}. Repo: https://github.com/${gitrepo}\" \
          }"
fi

if [[ "$(<<<"$box_info" jq "${jq_opts[@]}" '.box.versions[] | select(.name == $version) | .name // ""')" != "$BENTO_BOX_VERSION" ]]; then
    banner "Version $BENTO_BOX_VERSION"
    hcp_api "https://api.cloud.hashicorp.com/vagrant/2022-09-30/registry/{registry}/box/{box}/versions" \
            --data "{ \"name\": \"$BENTO_BOX_VERSION\", \"description\": \"Repo: [${gitrepo}](https://github.com/${gitrepo})\" }"
fi

if [[ "$(<<<"$box_info" jq "${jq_opts[@]}" '.box.versions[] | select(.name == $version) | .providers[] | select(.name == $provider) | .name // ""')" != "$VAGRANT_DEFAULT_PROVIDER" ]]; then
    banner "Provider $VAGRANT_DEFAULT_PROVIDER"
    hcp_api "https://api.cloud.hashicorp.com/vagrant/2022-09-30/registry/{registry}/box/{box}/version/{version}/providers" \
            --data "{ \"name\": \"${VAGRANT_DEFAULT_PROVIDER}\"}'"
    # {"provider":{"name":"virtualbox", "architectures":[], "created_at":"2024-11-08T23:49:50.269676019Z", "updated_at":"2024-11-08T23:49:50.269676019Z", "summary":{"architectures_count":"0", "architecture_types":[]}}}
    # {"code":6, "message":"provider \"virtualbox\" already exists for this version", "details":[]}
fi

if [[ "$(<<<"$box_info" jq "${jq_opts[@]}" '.box.versions[] | select(.name == $version) | .providers[] | select(.name == $provider) | .architectures[] | select(.architecture_type == $architecture) | .architecture_type // ""')" != "$BENTO_BOX_ARCHITECTURE" ]]; then
    banner "Architecture $BENTO_BOX_ARCHITECTURE"
    hcp_api "https://api.cloud.hashicorp.com/vagrant/2022-09-30/registry/{registry}/box/{box}/version/{version}/provider/{provider}/architectures" \
            --data "{ \"architecture_type\": \"${BENTO_BOX_ARCHITECTURE}\" }"
    # {"architecture":{"architecture_type":"amd64", "default":true, "box_data":{"download_url":null, "checksum":"", "checksum_type":"NONE", "size":null, "created_at":"2024-11-08T23:54:33.402608625Z", "updated_at":"2024-11-08T23:54:33.402608625Z"}, "created_at":"2024-11-08T23:54:33.401026216Z", "updated_at":"2024-11-08T23:54:33.401026216Z"}}
    # {"code":6, "message":"architecture with type \"amd64\" already exists", "details":[]}
fi
banner "Check if it is already uploaded($BENTO_BOX_ARCHITECTURE)"
download_url="$(
  hcp_api "https://api.cloud.hashicorp.com/vagrant/2022-09-30/registry/{registry}/box/{box}/version/{version}/provider/{provider}/architecture/{architecture}/download" |
    jq -r '.url // ""'
)"
if [[ -n "${download_url-}" && "$download_url" != null ]] && curl -LIs --fail "${download_url}"; then
    echo "$boxname ($BENTO_BOX_ARCHITECTURE) has been uploaded."
  exit 0
fi

banner "Prepare the provider for upload/get an upload URL($BENTO_BOX_ARCHITECTURE)"
response="$(hcp_api "https://api.cloud.hashicorp.com/vagrant/2022-09-30/registry/{registry}/box/{box}/version/{version}/provider/{provider}/architecture/{architecture}/upload")"
# {"url":"https://api.cloud.hashicorp.com/vagrant-archivist/v1/object/eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJrZXkiOiJjaGFpZmVuZy91YnVudHUtMjIuMDQtZG9ja2VyLTI2LjEuMS8yMDI0MDcuMjMuMC92aXJ0dWFsYm94L2YwNjM0NTIwLTllMmQtMTFlZi05YWM5LTdhOGZjMDYyZWE0YyIsIm1vZGUiOiJ3IiwiZXhwaXJlIjoxNzMxMTExMTYxLCJjYWxsYmFjayI6Imh0dHBzOi8vYXBpLmhhc2hpY29ycC5jbG91ZC92YWdyYW50LzIwMjItMDktMzAvcmVnaXN0cnkvY2hhaWZlbmcvYm94L3VidW50dS0yMi4wNC1kb2NrZXItMjYuMS4xL3ZlcnNpb24vMjAyNDA3LjIzLjAvcHJvdmlkZXIvdmlydHVhbGJveC9hcmNoaXRlY3R1cmUvYW1kNjQvY29tcGxldGUifQ.tf_io7BEI0EaPx-BVhG4Ui662PfX-mz7u9DF3bwkZ0I"}

upload_path="$(echo "$response" | jq -r .url)"

banner "Uploading $boxfile"
if type pv; then
  pv "$boxfile" | curl -Ls "$upload_path" --request PUT --silent --upload-file -
else
  curl -Ls "$upload_path" --request PUT --upload-file "$boxfile" --progress-bar
fi

echo "Release ${VAGRANT_CLOUD_USER}/${boxname} v$BENTO_BOX_VERSION"
hcp_api "https://api.cloud.hashicorp.com/vagrant/2022-09-30/registry/{registry}/box/{box}/version/{version}/release" \
  --request PUT

