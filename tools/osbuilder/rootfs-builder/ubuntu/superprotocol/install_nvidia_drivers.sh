#!/bin/bash


echo "Installing MLNX_OFED..."
apt update
apt install -y wget curl build-essential dkms

cd /tmp
wget -nv https://www.mellanox.com/downloads/ofed/MLNX_OFED-24.10-3.2.5.0/MLNX_OFED_LINUX-24.10-3.2.5.0-ubuntu24.04-x86_64.tgz
tar -xzf MLNX_OFED_LINUX-24.10-3.2.5.0-ubuntu24.04-x86_64.tgz
cd MLNX_OFED_LINUX-24.10-3.2.5.0-ubuntu24.04-x86_64
./mlnxofedinstall --hpc --without-fw-update --force \
  --kernel $(uname -r) \
  -v

echo "Installing NVIDIA drivers and components..."
cd /opt/deb/nvidia
dpkg -i *.deb
apt update
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    nvidia-open-570 \
    nvlink5-570 \
    nvidia-fabricmanager-570
systemctl enable nvidia-fabricmanager
systemctl enable nvidia-persistenced
cd /opt/deb
dpkg -i *.deb
