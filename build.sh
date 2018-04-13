#!/usr/bin/env bash
set -eu -o pipefail

VAGRANT_CLOUD_USER="${VAGRANT_CLOUD_USER:-chaifeng}"
VAGRANT_VAGRANTFILE="Vagrantfile-bento"

DOCKER_VERSION="${DOCKER_VERSION:-18.03}"
BENTO_UBUNTU="${BENTO_UBUNTU:-ubuntu-16.04}"
BENTO_UBUNTU_VERSION="${BENTO_UBUNTU_VERSION:-201803.24.0}"

export DOCKER_VERSION BENTO_UBUNTU_VERSION BENTO_UBUNTU VAGRANT_VAGRANTFILE

DOCKER="docker-$DOCKER_VERSION"
BOXNAME="${BENTO_UBUNTU}-${DOCKER}"
BOXFILE="${VAGRANT_CLOUD_USER}-bento-${BENTO_UBUNTU}-docker-${DOCKER_VERSION}.box"

GITREPO="$(git remote get-url origin)"
GITREPO="${GITREPO#git@github.com:}"
GITREPO="${GITREPO%.git}"

if [[ ! -f "$BOXFILE" ]]; then
  echo "Create ${BOXNAME}"
  vagrant destroy --force
  vagrant up
  vagrant halt
  vagrant package --output "$BOXFILE"
else
  echo "Box '${BOXNAME} is already created.'"
  download_url="$(curl \
      --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
      "https://app.vagrantup.com/api/v1/box/${VAGRANT_CLOUD_USER}/${BOXNAME}/version/${BENTO_UBUNTU_VERSION}" \
  | jq -r ".providers[0].download_url")"
  if curl -LI --fail "${download_url}"; then
      echo "$BOXNAME is alread uploaded."
      exit 0
  fi
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
    --data "{ \"version\": { \"version\": \"201803.24.0\", \"description\": \"Repo: [${GITREPO}](https://github.com/${GITREPO})\" } }"

echo ""
echo "Create a new provider"
curl \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  "https://app.vagrantup.com/api/v1/box/${VAGRANT_CLOUD_USER}/${BOXNAME}/version/$BENTO_UBUNTU_VERSION/providers" \
  --data "{ \"provider\": { \"name\": \"virtualbox\" } }"

echo ""
echo "Prepare the provider for upload/get an upload URL"
response="$(curl \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  "https://app.vagrantup.com/api/v1/box/${VAGRANT_CLOUD_USER}/${BOXNAME}/version/$BENTO_UBUNTU_VERSION/provider/virtualbox/upload")"

echo "Extract the upload URL from the response"
upload_path="$(echo "$response" | jq -r .upload_path)"

echo "Perform the upload"
curl "$upload_path" --request PUT --upload-file "$BOXFILE"

echo "Release the version"
curl \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  "https://app.vagrantup.com/api/v1/box/${VAGRANT_CLOUD_USER}/${BOXNAME}/version/$BENTO_UBUNTU_VERSION/release" \
  --request PUT

