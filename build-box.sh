#!/usr/bin/env bash
set -eu -o pipefail

if [[ "$-" = *x* ]]; then
  exec 99>>"${BASH_SOURCE%%.sh}.log"
  BASH_XTRACEFD=99
fi

VAGRANT_CLOUD_USER="${VAGRANT_CLOUD_USER:-chaifeng}"
VAGRANT_VAGRANTFILE="Vagrantfile-bento"

DOCKER_VERSION="${DOCKER_VERSION:-18.03}"
BENTO_UBUNTU="${BENTO_UBUNTU:-ubuntu-16.04}"
BENTO_UBUNTU_VERSION="${BENTO_UBUNTU_VERSION:-201806.08.0}"

VAGRANT_DEFAULT_PROVIDER="${VAGRANT_DEFAULT_PROVIDER:-virtualbox}"

export DOCKER_VERSION BENTO_UBUNTU_VERSION BENTO_UBUNTU VAGRANT_VAGRANTFILE

DOCKER="docker-$DOCKER_VERSION"
BOXNAME="${BENTO_UBUNTU}-${DOCKER}"
BOXFILE="${VAGRANT_CLOUD_USER}-bento-${BENTO_UBUNTU}-docker-${DOCKER_VERSION}-v${BENTO_UBUNTU_VERSION}-${VAGRANT_DEFAULT_PROVIDER}.box"

GITREPO="$(git remote get-url origin)"
GITREPO="${GITREPO#git@github.com:}"
GITREPO="${GITREPO%.git}"


if [[ "$VAGRANT_DEFAULT_PROVIDER" = vmware_* ]]; then
  VMWARE_PROVIDER=true
else
  VMWARE_PROVIDER=false
fi

if [[ ! -f "$BOXFILE" ]]; then
  echo "Create ${BOXNAME}"
  vagrant destroy --force
  vagrant up --provider="$VAGRANT_DEFAULT_PROVIDER"
  vagrant halt
  if "$VMWARE_PROVIDER"; then
      VMDK_FILE="$(find .vagrant/machines/default/"${VAGRANT_DEFAULT_PROVIDER}"/ -name disk-cl1.vmdk | head -1)"
      vmware-vdiskmanager -k "$VMDK_FILE"
  fi

  vagrant package --output "$BOXFILE"

  METADATA_FILE=./metadata.json
  if "$VMWARE_PROVIDER" && ! tar -zxOf "$BOXFILE" "$METADATA_FILE" | grep -F "$VAGRANT_DEFAULT_PROVIDER" &>/dev/null; then
    mv "$BOXFILE" "$BOXFILE".gz
    gunzip "$BOXFILE".gz
    echo '{"provider":"vmware_fusion"}' > "$METADATA_FILE"
    tar -uf "$BOXFILE" "$METADATA_FILE"
    rm "$METADATA_FILE"
    gzip "$BOXFILE"
    mv "$BOXFILE".gz "$BOXFILE"
  fi
else
  echo "Box ${BOXNAME} v$BENTO_UBUNTU_VERSION is already created."
fi

echo ""
echo "Create a new box."
curl \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  "https://app.vagrantup.com/api/v1/boxes" \
  --data "{ \"box\": { \
              \"username\": \"${VAGRANT_CLOUD_USER}\" \
              , \"name\": \"${BOXNAME}\" \
              , \"is_private\": false \
              , \"short_description\": \
                   \"Ubuntu ${BENTO_UBUNTU#ubuntu-} with Docker CE ${DOCKER_VERSION}, based on Bento/${BENTO_UBUNTU}. Repo: https://github.com/${GITREPO}\" \
              } \
          }"

echo ""
echo "Create a new version"
curl \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
    "https://app.vagrantup.com/api/v1/box/${VAGRANT_CLOUD_USER}/${BOXNAME}/versions" \
    --data "{ \"version\": { \"version\": \"$BENTO_UBUNTU_VERSION\", \"description\": \"Repo: [${GITREPO}](https://github.com/${GITREPO})\" } }"

echo ""
echo "Create a new provider"
curl \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  "https://app.vagrantup.com/api/v1/box/${VAGRANT_CLOUD_USER}/${BOXNAME}/version/$BENTO_UBUNTU_VERSION/providers" \
  --data "{ \"provider\": { \"name\": \"${VAGRANT_DEFAULT_PROVIDER}\" } }"

echo ""
echo "Check if it is already uploaded"
download_url="$(curl \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  "https://app.vagrantup.com/api/v1/box/${VAGRANT_CLOUD_USER}/${BOXNAME}/version/${BENTO_UBUNTU_VERSION}" \
  | jq -r ".providers[] | if .name == \"${VAGRANT_DEFAULT_PROVIDER}\" then .download_url else empty end")"
if curl -LI --fail "${download_url}"; then
  echo "$BOXNAME is already uploaded."
  exit 0
fi

echo ""
echo "Prepare the provider for upload/get an upload URL"
response="$(curl \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  "https://app.vagrantup.com/api/v1/box/${VAGRANT_CLOUD_USER}/${BOXNAME}/version/$BENTO_UBUNTU_VERSION/provider/${VAGRANT_DEFAULT_PROVIDER}/upload")"

echo "Extract the upload URL from the response"
upload_path="$(echo "$response" | jq -r .upload_path)"

echo "Perform the upload"
if type pv; then
  pv "$BOXFILE" | curl "$upload_path" --request PUT --upload-file - --silent
else
  curl "$upload_path" --request PUT --upload-file "$BOXFILE" --progress-bar
fi

echo "Release the version"
curl \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  "https://app.vagrantup.com/api/v1/box/${VAGRANT_CLOUD_USER}/${BOXNAME}/version/$BENTO_UBUNTU_VERSION/release" \
  --request PUT

