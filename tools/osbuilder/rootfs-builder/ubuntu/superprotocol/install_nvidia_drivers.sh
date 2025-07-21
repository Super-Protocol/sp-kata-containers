#!/bin/bash

apt update

cd /opt/deb/nvidia
dpkg -i *.deb
apt update
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends nvidia-driver-570-open nvidia-fabricmanager-570 nvlink5-570 libibumad3 infiniband-diags
systemctl enable nvidia-fabricmanager
cd /opt/deb
dpkg -i *.deb
