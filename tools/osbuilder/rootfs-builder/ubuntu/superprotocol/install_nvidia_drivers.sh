#!/bin/bash

apt update

cd /opt/deb/nvidia
dpkg -i *.deb
echo "Installing UCX..."
wget https://developer.download.nvidia.com/hpc-sdk/ubuntu/DEB-GPG-KEY-NVIDIA-HPC-SDK
apt-key add DEB-GPG-KEY-NVIDIA-HPC-SDK
echo "deb https://developer.download.nvidia.com/hpc-sdk/ubuntu/amd64 /" > /etc/apt/sources.list.d/nvhpc.list
apt update
DEBIAN_FRONTEND=noninteractive apt install -y ucx libucx-dev ucx-tools
echo "Installing NVIDIA drivers and components..."
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    nvidia-open-570 \
    nvlink5-570 \
    nvidia-fabricmanager-570 \
    libibumad3 \
    infiniband-diags
systemctl enable nvidia-fabricmanager
systemctl enable nvidia-persistenced
cd /opt/deb
dpkg -i *.deb
