#!/bin/bash

apt update
cd /opt/deb
dpkg -i *.deb
cd /opt/deb/nvidia
dpkg -i *.deb

apt update
apt install -y rdma-core ibverbs-utils infiniband-diags libibverbs1 libibverbs-dev librdmacm1 librdmacm-dev

echo "Installing NVIDIA drivers and components..."
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    nvidia-open-570 \
    nvlink5-570 \
    nvidia-fabricmanager-570
systemctl enable nvidia-fabricmanager
systemctl enable nvidia-persistenced
