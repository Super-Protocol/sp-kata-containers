#!/bin/bash

apt update

cd /opt/deb/nvidia
dpkg -i *.deb
apt update
echo "Installing UCX..."
DEBIAN_FRONTEND=noninteractive apt install -y libucx-dev ucx-tools
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
