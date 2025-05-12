#!/bin/bash

set -x

SUPER_REGISTRY_HOST="registry.superprotocol.local";
SUPER_CERTS_DIR="/etc/super/certs";
SUPER_CERT_FILEPATH="$SUPER_CERTS_DIR/$SUPER_REGISTRY_HOST";

/var/lib/rancher/rke2/bin/kubectl \
    create secret tls docker-registry-tls \
    --namespace super-protocol \
    "--cert=$SUPER_CERT_FILEPATH.crt" \
    "--key=$SUPER_CERT_FILEPATH.key" \
    --dry-run=client \
    --output=yaml > /var/lib/rancher/rke2/server/manifests/docker-registry-tls.yaml

set +x
