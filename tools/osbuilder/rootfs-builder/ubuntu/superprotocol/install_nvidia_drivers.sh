#!/bin/bash

apt update

cd /opt/deb/nvidia
dpkg -i *.deb
apt update
apt list --all-versions 2>/dev/null | grep nvidia | grep -E "(570|fabricmanager)"
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends nvidia-driver-570-server-open=570.133.20-0ubuntu0.24.04.1 nvidia-fabricmanager-570=570.133.20-0ubuntu0.24.04.1
cd /opt/deb
dpkg -i *.deb
