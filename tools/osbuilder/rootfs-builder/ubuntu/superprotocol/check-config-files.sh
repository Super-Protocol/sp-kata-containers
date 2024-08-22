#!/bin/bash

# Define source and destination paths
declare -A files=(
    ["/etc/super/var/lib/rancher/rke2/rke2-pss.yaml"]="/var/lib/rancher/rke2/rke2-pss.yaml"
    ["/etc/super/var/lib/rancher/rke2/server/manifests/k8s-infra.yaml"]="/var/lib/rancher/rke2/server/manifests/k8s-infra.yaml"
    ["/etc/super/var/lib/rancher/rke2/agent/etc/containerd/config.toml.tmpl"]="/var/lib/rancher/rke2/agent/etc/containerd/config.toml.tmpl"
    ["/etc/super/etc/iscsi/iscsid.conf"]="/etc/iscsi/iscsid.conf"
)

# Check and copy files if they do not exist
for src in "${!files[@]}"; do
    dest="${files[$src]}"
    dest_dir=$(dirname "$dest")
    # Create destination directory if it does not exist
    if [ ! -d "$dest_dir" ]; then
        mkdir -p "$dest_dir"
    fi
    # Copy file if it does not exist
    if [ ! -f "$dest" ]; then
        cp -v "$src" "$dest"
    fi
done

# Generate a unique iSCSI InitiatorName
NAMEFILE=/etc/iscsi/initiatorname.iscsi
if [ ! -e $NAMEFILE ] && [ -z "$2" ] ; then
    INAME=$(iscsi-iname -p iqn.2004-10.com.ubuntu:01)
    if [ -n "$INAME" ] ; then
        echo "## DO NOT EDIT OR REMOVE THIS FILE!" > $NAMEFILE
        echo "## If you remove this file, the iSCSI daemon will not start." >> $NAMEFILE
        echo "## If you change the InitiatorName, existing access control lists" >> $NAMEFILE
        echo "## may reject this initiator.  The InitiatorName must be unique">> $NAMEFILE
        echo "## for each iSCSI initiator.  Do NOT duplicate iSCSI InitiatorNames." >> $NAMEFILE
        printf "InitiatorName=%s\n" "$INAME" >> $NAMEFILE
        chmod 600 $NAMEFILE
    else
        echo "Error: failed to generate an iSCSI InitiatorName, driver cannot start."
        echo
        exit 1;
    fi
fi
