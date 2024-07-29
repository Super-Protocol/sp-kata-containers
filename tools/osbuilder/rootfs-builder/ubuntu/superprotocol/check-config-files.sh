#!/bin/bash

# Define source and destination paths
declare -A files=(
    ["/etc/super/var/lib/rancher/rke2/rke2-pss.yaml"]="/var/lib/rancher/rke2/rke2-pss.yaml"
    ["/etc/super/var/lib/rancher/rke2/server/manifests/k8s-infra.yaml"]="/var/lib/rancher/rke2/server/manifests/k8s-infra.yaml"
    ["/etc/super/etc/iscsi/iscsid.conf"]="/etc/iscsi/iscsid.conf"
    ["/etc/super/etc/iscsi/initiatorname.iscsi"]="/etc/iscsi/initiatorname.iscsi"
)

# Check and copy files if they do not exist
for src in "${!files[@]}"; do
    dest="${files[$src]}"
    if [ ! -f "$dest" ]; then
        cp -v "$src" "$dest"
    fi
done
