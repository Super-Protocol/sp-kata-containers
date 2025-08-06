#!/bin/bash

CONTAINER_NAME="pki-authority"

if lxc-info -n "$CONTAINER_NAME" &>/dev/null; then
  echo "Container '$CONTAINER_NAME' already exists."
else
  echo "Container '$CONTAINER_NAME' not found. Creating..."
  lxc-create -n "$CONTAINER_NAME" -t oci -- --url docker-archive://root/containers/pki-authority.tar
  echo "Container '$CONTAINER_NAME' created."
fi