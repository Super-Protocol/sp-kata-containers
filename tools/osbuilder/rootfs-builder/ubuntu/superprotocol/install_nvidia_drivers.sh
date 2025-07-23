#!/bin/bash

apt update
cd /opt/deb
dpkg -i *.deb
cd /opt/deb/nvidia
dpkg -i *.deb

echo "Installing DOCA_OFED..."
apt update
apt install -y wget
apt remove mft -y
apt autoremove -y
apt clean
apt update

wget --no-verbose https://www.mellanox.com/downloads/DOCA/DOCA_v3.0.0/host/doca-host_3.0.0-058000-25.04-ubuntu2404_amd64.deb
dpkg -i doca-host_3.0.0-058000-25.04-ubuntu2404_amd64.deb
apt-get update
apt-get -y install doca-ofed

echo "Installing NVIDIA drivers and components..."
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    nvidia-open-570 \
    nvlink5-570 \
    nvidia-fabricmanager-570
systemctl enable nvidia-fabricmanager
systemctl enable nvidia-persistenced
