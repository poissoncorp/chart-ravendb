#!/bin/bash

set -e

# install depts
apt-get update -qq
apt-get install unzip curl sudo jq -qq

# install kubectl
echo "Installing kubectl..."
cd /usr
mkdir kubectl
cd kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# copy zip from the secret
echo "Copying RavenDB setup package to /ravendb"
cp "$(find /usr/ravendb/*.zip)" /ravendb/pack.zip
cd /ravendb

# unzip the pack
echo "Extracting files from the pack..."
mkdir /ravendb/ravendb-setup-package
unzip -qq pack.zip -d ./ravendb-setup-package/ > /dev/null
cd ravendb-setup-package


echo "Reading RavenDB license string..."
license_string="$( tr -d '\r\n' < license.json )"
echo "License loaded, license id: $( jq '.Id' license.json || exit 1 )"
echo "Reading envrionmental values from the settings.json"
setup_mode="$( jq -r '."Setup.Mode"' A/settings.json )"
echo "Setup.Mode is $setup_mode"

if [ "$setup_mode" = "LetsEncrypt" ]; then
lets_encrypt_email="$( jq -r '."Security.Certificate.LetsEncrypt.Email"' A/settings.json )"
else
lets_encrypt_email="not found"
fi

echo "Security.Certificate.LetsEncrypt.Email is $lets_encrypt_email"
echo "Updating ravendb-env config map"
kubectl get cm -n ravendb -o json ravendb-env | jq --arg license "$license_string" "(.data[\"raven_setup_mode\"]=\"$setup_mode\" | .data[\"raven_security_certificate_letsencrypt_email\"]=\"$lets_encrypt_email\" | .data[\"raven_license\"]=\$license)" | kubectl apply -f -
echo "Updating ravendb-license config map"


echo "Reading node tag from the HOSTNAME environmental..."
node_tag="$(env | grep HOSTNAME | cut -f 2 -d '-')"
cd "${node_tag^^}"

# update secret
echo "Updating secret using kubectl get and kubectl apply..."
kubectl get secret ravendb-certs -o json -n ravendb | jq ".data[\"$node_tag.pfx\"]=\"$(cat ./*certificate* | base64)\"" | kubectl apply -f -
