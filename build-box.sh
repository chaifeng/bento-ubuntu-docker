#!/usr/bin/env bash
set -eu -o pipefail

if [[ "$-" = *x* ]]; then
  exec 99>>"${BASH_SOURCE%%.sh}.log"
  BASH_XTRACEFD=99
fi

VAGRANT_CLOUD_USER="${VAGRANT_CLOUD_USER:-chaifeng}"
VAGRANT_VAGRANTFILE="Vagrantfile-bento"

DOCKER_VERSION="${DOCKER_VERSION:-20.10.17}"
BENTO_BOX="${BENTO_BOX:-ubuntu-20.04}"
BENTO_BOX_VERSION="${BENTO_BOX_VERSION:-202112.19.0}"

VAGRANT_DEFAULT_PROVIDER="${VAGRANT_DEFAULT_PROVIDER:-virtualbox}"

export DOCKER_VERSION BENTO_BOX_VERSION BENTO_BOX VAGRANT_VAGRANTFILE

if [[ "$BENTO_BOX" = *-arm64 ]]; then
  BENTO_BOX_ARCHITECTURE="${BENTO_BOX_ARCHITECTURE:-arm64}"
  boxname="${BENTO_BOX%-arm64}-docker-$DOCKER_VERSION-arm64"
  boxfile="${VAGRANT_CLOUD_USER}-bento-${boxname}-v${BENTO_BOX_VERSION}-${VAGRANT_DEFAULT_PROVIDER}.box"
else
  BENTO_BOX_ARCHITECTURE="${BENTO_BOX_ARCHITECTURE:-amd64}"
  boxname="${BENTO_BOX}-docker-$DOCKER_VERSION"
  boxfile="${VAGRANT_CLOUD_USER}-bento-${boxname}-${BENTO_BOX_ARCHITECTURE}-v${BENTO_BOX_VERSION}-${VAGRANT_DEFAULT_PROVIDER}.box"
fi


gitrepo="$(git remote get-url origin)"
gitrepo="${gitrepo#git@github.com:}"
gitrepo="${gitrepo%.git}"


if [[ "$VAGRANT_DEFAULT_PROVIDER" = vmware_* ]]; then
  is_vmware_provider=true
else
  is_vmware_provider=false
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

# https://developer.hashicorp.com/vagrant/vagrant-cloud/api/v2
echo ""
echo "Create a new box."
bento_box_desc="${BENTO_BOX//-/ }"
curl \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  "https://app.vagrantup.com/api/v2/boxes" \
  --data "{ \"box\": { \
              \"username\": \"${VAGRANT_CLOUD_USER}\" \
              , \"name\": \"${boxname}\" \
              , \"is_private\": false \
              , \"short_description\": \
                   \"${bento_box_desc^} with Docker CE ${DOCKER_VERSION}, based on Bento/${BENTO_BOX}. Repo: https://github.com/${gitrepo}\" \
              } \
          }"

echo ""
echo "Create a new version"
curl \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
    "https://app.vagrantup.com/api/v2/box/${VAGRANT_CLOUD_USER}/${boxname}/versions" \
    --data "{ \"version\": { \"version\": \"$BENTO_BOX_VERSION\", \"description\": \"Repo: [${gitrepo}](https://github.com/${gitrepo})\" } }"

echo ""
echo "Create a new provider($BENTO_BOX_ARCHITECTURE)"
curl \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  "https://app.vagrantup.com/api/v2/box/${VAGRANT_CLOUD_USER}/${boxname}/version/$BENTO_BOX_VERSION/providers" \
  --data "{ \"provider\": { \"name\": \"${VAGRANT_DEFAULT_PROVIDER}\", \"architecture\": \"${BENTO_BOX_ARCHITECTURE}\" } }"

echo ""
echo "Check if it is already uploaded($BENTO_BOX_ARCHITECTURE)"
download_url="$(curl \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  "https://app.vagrantup.com/api/v2/box/${VAGRANT_CLOUD_USER}/${boxname}/version/${BENTO_BOX_VERSION}" \
  | jq -r --arg p "${VAGRANT_DEFAULT_PROVIDER}" --arg a "${BENTO_BOX_ARCHITECTURE}" \
       '.providers[] | select(.name == $p and .architecture == $a) | .download_url // ""'
)"
if [[ -n "$download_url" ]] && curl -LI --fail "${download_url}"; then
    echo "$boxname ($BENTO_BOX_ARCHITECTURE) has been uploaded."
  exit 0
fi

echo ""
echo "Prepare the provider for upload/get an upload URL($BENTO_BOX_ARCHITECTURE)"
response="$(curl \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  "https://app.vagrantup.com/api/v2/box/${VAGRANT_CLOUD_USER}/${boxname}/version/$BENTO_BOX_VERSION/provider/${VAGRANT_DEFAULT_PROVIDER}/${BENTO_BOX_ARCHITECTURE}/upload")"

echo "Extract the upload URL from the response"
upload_path="$(echo "$response" | jq -r .upload_path)"

echo "Perform the upload"
if type pv; then
  pv "$boxfile" | curl "$upload_path" --request PUT --silent --upload-file -
else
  curl "$upload_path" --request PUT --upload-file "$boxfile" --progress-bar
fi

echo "Release the version"
curl \
  --header "Authorization: Bearer $VAGRANT_CLOUD_TOKEN" \
  "https://app.vagrantup.com/api/v2/box/${VAGRANT_CLOUD_USER}/${boxname}/version/$BENTO_BOX_VERSION/release" \
  --request PUT

