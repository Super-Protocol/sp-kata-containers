#!/bin/bash

apt update
apt install -y wget apt-utils dkms

cd /opt/deb
dpkg -i *.deb
cd /opt/deb/nvidia
dpkg -i *.deb

apt update
cd /tmp

wget https://www.mellanox.com/downloads/DOCA/DOCA_v3.0.0/host/doca-host_3.0.0-058000-25.04-ubuntu2404_amd64.deb
dpkg -i doca-host_3.0.0-058000-25.04-ubuntu2404_amd64.deb
apt-get update
apt install -y doca-extra
/opt/mellanox/doca/tools/doca-kernel-support

echo "Installing NVIDIA drivers and components..."
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    nvidia-open-570 \
    nvlink5-570 \
    nvidia-fabricmanager-570
systemctl enable nvidia-fabricmanager
systemctl enable nvidia-persistenced
