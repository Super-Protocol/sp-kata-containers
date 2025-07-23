#!/bin/bash

apt update
apt install -y wget

cd /opt/deb
dpkg -i *.deb
cd /opt/deb/nvidia
dpkg -i *.deb

wget --no-verbose https://www.mellanox.com/downloads/DOCA/DOCA_v3.0.0/host/doca-host_3.0.0-058000-25.04-ubuntu2404_amd64.deb
dpkg -i doca-host_3.0.0-058000-25.04-ubuntu2404_amd64.deb

wget https://www.mellanox.com/downloads/MFT/mft-4.32.0-120-x86_64-deb.tgz
tar -xzf mft-4.32.0-120-x86_64-deb.tgz
cd mft-4.32.0-120-x86_64-deb
./install.sh

apt update
apt -y install doca-all

echo "Installing NVIDIA drivers and components..."
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    nvidia-open-570 \
    nvlink5-570 \
    nvidia-fabricmanager-570
systemctl enable nvidia-fabricmanager
systemctl enable nvidia-persistenced
