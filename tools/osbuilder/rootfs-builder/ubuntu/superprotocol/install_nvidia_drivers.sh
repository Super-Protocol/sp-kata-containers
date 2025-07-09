#!/bin/bash

apt update

cd /opt/deb/nvidia
dpkg -i *.deb
apt update
#apt list --all-versions 2>/dev/null | grep nvidia | grep -E "(570|fabricmanager)"
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    nvidia-headless-no-dkms-570-open=570.133.20-0ubuntu1 \
    nvidia-fabricmanager-570=570.133.20-1 \
    libnvidia-nscq-570=570.133.20-1 \
    nvidia-utils-570=570.133.20-0ubuntu1 \
    libnvidia-compute-570=570.133.20-0ubuntu1 \
    nvidia-kernel-common-570=570.133.20-0ubuntu1
systemctl enable nvidia-fabricmanager
systemctl enable nvidia-persistenced
cd /opt/deb
dpkg -i *.deb
