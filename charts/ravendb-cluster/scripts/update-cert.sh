#!/bin/bash

function update_secret {
    # read stdin
    echo "Reading certificate from stdin..."
    read -re new_cert
    
    # install depts
    echo "Updating OS..."
    apt-get update -qq
    echo "Installing curl sudo and jq..."
    apt-get install curl sudo jq -qq

    # install kubectl

    echo "Installing kubectl..."
    cd /usr || exit
    mkdir kubectl
    cd kubectl || exit
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

    # get node tag
    echo "Getting node tag from HOSTNAME environmental:..."
    node_tag="$(env | grep HOSTNAME | cut -f 2 -d '-')"
    echo "Node tag: $node_tag"
    
    previous_content=$(cat /ravendb/certs/"$node_tag".pfx)
    # update secret
    echo "Updating sever certificate on node $node_tag by updating ravendb-certs secret"
    kubectl get secret ravendb-certs -o json -n ravendb | jq ".data[\"$node_tag.pfx\"]=\"$new_cert\"" | kubectl apply -f -

    content=$(cat "/ravendb/certs/$node_tag.pfx")

    if [[ $previous_content == "$content" ]]; then
        echo "ERROR: The updated certificate (mounted secret path) is identical to the previous one..."
        exit 111
    fi
}

update_secret >> /var/log/ravendb-cert-update-logs
