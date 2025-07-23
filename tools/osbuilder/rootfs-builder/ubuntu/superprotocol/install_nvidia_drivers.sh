#!/bin/bash

apt update
apt install -y wget apt-utils dkms

cd /opt/deb
dpkg -i *.deb
cd /opt/deb/nvidia
dpkg -i *.deb

apt update
cd /tmp

apt install -y doca-extra
/opt/mellanox/doca/tools/doca-kernel-support

echo "Installing NVIDIA drivers and components..."
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    nvidia-open-570 \
    nvlink5-570 \
    nvidia-fabricmanager-570
systemctl enable nvidia-fabricmanager
systemctl enable nvidia-persistenced
