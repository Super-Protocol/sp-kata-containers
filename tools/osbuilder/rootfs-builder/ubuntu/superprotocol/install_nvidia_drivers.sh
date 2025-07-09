#!/bin/bash

apt update

cd /opt/deb/nvidia
dpkg -i *.deb
apt update
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends nvidia-driver-570-server-open=570.133.20-0ubuntu0.24.04.1 nvidia-fabricmanager-570=570.133.20-0ubuntu0.24.04.1
cd /opt/deb
dpkg -i *.deb
