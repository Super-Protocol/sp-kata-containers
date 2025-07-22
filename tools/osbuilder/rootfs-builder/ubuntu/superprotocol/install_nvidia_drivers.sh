#!/bin/bash


echo "Installing MLNX_OFED..."
apt update
apt install -y linux-headers-generic || true
apt install -y build-essential wget dkms autotools-dev libnl-route-3-200 flex libusb-1.0-0 tk libpci3 bison libltdl-dev autoconf libnl-3-dev libnuma1 ethtool graphviz libnl-route-3-dev debhelper pkg-config libfuse2t64 pciutils swig lsof chrpath m4 libgfortran5 tcl automake quilt gfortran

cd /tmp
wget -nv https://www.mellanox.com/downloads/ofed/MLNX_OFED-24.10-3.2.5.0/MLNX_OFED_LINUX-24.10-3.2.5.0-ubuntu24.04-x86_64.tgz
tar -xzf MLNX_OFED_LINUX-24.10-3.2.5.0-ubuntu24.04-x86_64.tgz
cd MLNX_OFED_LINUX-24.10-3.2.5.0-ubuntu24.04-x86_64

./mlnxofedinstall --hpc --without-fw-update --force \
  --add-kernel-support --skip-distro-check --without-depcheck \
  -k 6.12.13-nvidia-gpu-confidential -v
  
echo "Installing NVIDIA drivers and components..."
cd /opt/deb/nvidia
dpkg -i *.deb
apt update
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    nvidia-open-570 \
    nvlink5-570 \
    nvidia-fabricmanager-570
systemctl enable nvidia-fabricmanager
systemctl enable nvidia-persistenced
cd /opt/deb
dpkg -i *.deb
