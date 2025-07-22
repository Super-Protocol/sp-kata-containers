#!/bin/bash

apt update
cd /opt/deb
dpkg -i *.deb
cd /opt/deb/nvidia
dpkg -i *.deb


echo "Installing MLNX_OFED..."
apt update
apt install -y build-essential wget dkms autotools-dev

cd /tmp
wget -nv https://www.mellanox.com/downloads/ofed/MLNX_OFED-24.10-3.2.5.0/MLNX_OFED_LINUX-24.10-3.2.5.0-ubuntu24.04-x86_64.tgz
tar -xzf MLNX_OFED_LINUX-24.10-3.2.5.0-ubuntu24.04-x86_64.tgz
cd MLNX_OFED_LINUX-24.10-3.2.5.0-ubuntu24.04-x86_64

./mlnxofedinstall --hpc --without-fw-update --force --dkms --add-kernel-support -k 6.12.13-nvidia-gpu-confidential -v

echo "Installing NVIDIA drivers and components..."
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    nvidia-open-570 \
    nvlink5-570 \
    nvidia-fabricmanager-570
systemctl enable nvidia-fabricmanager
systemctl enable nvidia-persistenced
