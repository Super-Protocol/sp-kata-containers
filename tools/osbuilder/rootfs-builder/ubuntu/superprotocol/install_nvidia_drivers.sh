#!/bin/bash

apt update
cd /opt/deb
dpkg -i *.deb
cd /opt/deb/nvidia
dpkg -i *.deb

apt update
apt install -y wget dkms

echo "Installing MFT 4.32.0-120 manually..."
cd /tmp
echo "Downloading MFT 4.32.0-120..."
wget --no-verbose https://www.mellanox.com/downloads/MFT/mft-4.32.0-120-x86_64-deb.tgz

echo "Extracting MFT package..."
tar -xzf mft-4.32.0-120-x86_64-deb.tgz
cd mft-4.32.0-120-x86_64-deb

echo "Installing MFT..."
./install.sh --without-kernel

echo "Installing DOCA_OFED..."
cd /tmp
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
