#!/bin/bash

set -x
apt update

cd /opt/deb/nvidia
dpkg -i *.deb
apt update
apt install -y --no-install-recommends gcc-13
if ! DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends nvidia-driver-550-open; then
    echo "Error when install nvidia drivers"
    cat /var/lib/dkms/nvidia/550.163.01/build/make.log || echo "make.log not found"
    exit 1
fi
cd /opt/deb

if ! dpkg -i *.deb; then
    echo "Error when install nvidia drivers 2"
    dpkg -l
    cat /var/lib/dkms/nvidia/550.163.01/build/make.log || echo "make.log not found"
    exit 1
fi
