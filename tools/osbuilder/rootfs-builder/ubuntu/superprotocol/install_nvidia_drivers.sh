#!/bin/bash

apt update
apt install -y wget apt-utils

cd /opt/deb
dpkg -i *.deb
cd /opt/deb/nvidia
dpkg -i *.deb

wget -nv https://www.mellanox.com/downloads/MFT/mft-4.32.0-120-x86_64-deb.tgz
tar -xzf mft-4.32.0-120-x86_64-deb.tgz
cd mft-4.32.0-120-x86_64-deb
./install.sh

wget -nv https://www.mellanox.com/downloads/DOCA/DOCA_v2.10.0/host/doca-host_2.10.0-093000-25.01-ubuntu2404_amd64.deb
dpkg -i doca-host_2.10.0-093000-25.01-ubuntu2404_amd64.deb
apt-get update
apt-get -y install doca-ofed

echo "Installing NVIDIA drivers and components..."
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    nvidia-open-570 \
    nvlink5-570 \
    nvidia-fabricmanager-570
systemctl enable nvidia-fabricmanager
systemctl enable nvidia-persistenced
