#!/bin/bash

apt update

cd /opt/deb/nvidia
dpkg -i *.deb
apt update
#apt list --all-versions 2>/dev/null | grep nvidia | grep -E "(570|fabricmanager)"
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends --allow-downgrades nvidia-driver-570-open nvidia-fabricmanager-570
systemctl enable nvidia-persistenced
cd /opt/deb
dpkg -i *.deb
