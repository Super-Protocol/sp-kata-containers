#!/bin/bash

set -e
apt update

cd /opt/deb/nvidia
dpkg -i *.deb
apt update
if ! DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends nvidia-driver-550-open; then
    echo "Error when install nvidia drivers"
    cat /var/lib/dkms/nvidia/550.163.01/build/make.log
    exit 1
fi
cd /opt/deb
dpkg -i *.deb
