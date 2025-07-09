#!/bin/bash

apt update

cd /opt/deb/nvidia
dpkg -i *.deb
apt update
apt list --all-versions 2>/dev/null | grep nvidia | grep -E "(570|fabricmanager)"
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    nvidia-driver-570-open=570.133.20-0ubuntu1 \
    libnvidia-gl-570=570.133.20-0ubuntu1 \
    nvidia-dkms-570-open=570.133.20-0ubuntu1 \
    nvidia-kernel-common-570=570.133.20-0ubuntu1 \
    nvidia-kernel-source-570-open=570.133.20-0ubuntu1 \
    libnvidia-compute-570=570.133.20-0ubuntu1 \
    libnvidia-extra-570=570.133.20-0ubuntu1 \
    nvidia-compute-utils-570=570.133.20-0ubuntu1 \
    libnvidia-decode-570=570.133.20-0ubuntu1 \
    libnvidia-encode-570=570.133.20-0ubuntu1 \
    nvidia-utils-570=570.133.20-0ubuntu1 \
    xserver-xorg-video-nvidia-570=570.133.20-0ubuntu1 \
    libnvidia-cfg1-570=570.133.20-0ubuntu1 \
    libnvidia-fbc1-570=570.133.20-0ubuntu1 \
    nvidia-fabricmanager-570=570.133.20-1 \
    libnvidia-nscq-570=570.133.20-1    
cd /opt/deb
dpkg -i *.deb
