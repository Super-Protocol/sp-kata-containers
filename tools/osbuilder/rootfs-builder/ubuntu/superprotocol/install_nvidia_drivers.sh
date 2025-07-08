#!/bin/bash

apt update

cd /opt/deb/nvidia
dpkg -i *.deb
apt update
DEBIAN_FRONTEND=noninteractive apt install -y cuda-toolkit-12-8 nvidia-driver-570-open nvidia-fabricmanager-570
cd /opt/deb
dpkg -i *.deb
