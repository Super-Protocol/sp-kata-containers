#!/bin/bash

apt update
apt install -y wget apt-utils dkms

cd /opt/deb
dpkg -i *.deb
cd /opt/deb/nvidia
dpkg -i *.deb

apt update
cd /tmp

echo "Installing NVIDIA drivers and components..."
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends nvidia-open-575
