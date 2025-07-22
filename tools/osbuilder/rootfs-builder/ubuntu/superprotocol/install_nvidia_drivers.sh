#!/bin/bash

apt update

echo "Installing MLNX_OFED..."
apt install -y wget curl build-essential dkms

cd /tmp
wget https://www.mellanox.com/downloads/ofed/MLNX_OFED-24.10-3.2.5.0/MLNX_OFED_LINUX-24.10-3.2.5.0-ubuntu24.04-x86_64.tgz
tar -xzf MLNX_OFED_LINUX-24.10-3.2.5.0-ubuntu24.04-x86_64.tgz
cd MLNX_OFED_LINUX-24.10-3.2.5.0-ubuntu24.04-x86_64
./mlnxofedinstall --hpc --user-space-only --without-fw-update --force -v

apt update
echo "Installing NVIDIA drivers and components..."
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    nvidia-open-570 \
    nvlink5-570 \
    nvidia-fabricmanager-570
systemctl enable nvidia-fabricmanager
systemctl enable nvidia-persistenced
cd /opt/deb
dpkg -i *.deb
