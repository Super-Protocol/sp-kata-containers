#!/bin/bash

apt update
cd /opt/deb
dpkg -i *.deb
cd /opt/deb/nvidia
dpkg -i *.deb

show_mlnx_logs() {
    echo "=== SEARCHING FOR MLNX LOGS ==="
    
    MAIN_LOG=$(find /tmp -name "mlnx_ofed_iso.*.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
    if [[ -n "$MAIN_LOG" && -f "$MAIN_LOG" ]]; then
        echo "=== MAIN MLNX LOG: $MAIN_LOG ==="
        cat "$MAIN_LOG"
        echo "=== END MAIN LOG ==="
    fi
    
    OFED_LOGS_DIR=$(find /tmp -path "*/OFED.*.logs" -type d 2>/dev/null | head -1)
    if [[ -n "$OFED_LOGS_DIR" && -d "$OFED_LOGS_DIR" ]]; then
        echo "=== OFED LOGS DIRECTORY: $OFED_LOGS_DIR ==="
        ls -la "$OFED_LOGS_DIR"
        
        if [[ -f "$OFED_LOGS_DIR/general.log" ]]; then
            echo "=== GENERAL LOG ==="
            cat "$OFED_LOGS_DIR/general.log"
            echo "=== END GENERAL LOG ==="
        fi
        
        KERNEL_LOG=$(find "$OFED_LOGS_DIR" -name "*kernel*.log" -type f | head -1)
        if [[ -n "$KERNEL_LOG" && -f "$KERNEL_LOG" ]]; then
            echo "=== KERNEL BUILD LOG: $KERNEL_LOG ==="
            cat "$KERNEL_LOG"
            echo "=== END KERNEL BUILD LOG ==="
        fi
        
        find "$OFED_LOGS_DIR" -name "*.log" -type f | while read logfile; do
            echo "=== LOG FILE: $logfile ==="
            cat "$logfile"
            echo "=== END LOG FILE ==="
        done
    fi
    
    echo "=== ALL MLNX RELATED LOGS IN /tmp ==="
    find /tmp -name "*mlnx*" -name "*.log" -type f 2>/dev/null | while read logfile; do
        echo "=== FOUND LOG: $logfile ==="
        cat "$logfile"
        echo "=== END FOUND LOG ==="
    done
}


echo "Installing MLNX_OFED..."
apt update
apt install -y build-essential wget dkms autotools-dev apt-utils gcc dh-autoreconf debhelper dh-dkms quilt chrpath pkg-config bzip2 autoconf automake make

cd /tmp
wget -nv https://www.mellanox.com/downloads/ofed/MLNX_OFED-24.10-3.2.5.0/MLNX_OFED_LINUX-24.10-3.2.5.0-ubuntu24.04-x86_64.tgz
tar -xzf MLNX_OFED_LINUX-24.10-3.2.5.0-ubuntu24.04-x86_64.tgz
cd MLNX_OFED_LINUX-24.10-3.2.5.0-ubuntu24.04-x86_64

./mlnxofedinstall  -vvv --with-nvmf --force --without-fw-update \
  --add-kernel-support -k 6.12.13-nvidia-gpu-confidential

if [[ $? -ne 0 ]]; then
    echo "MLNX_OFED installation failed, showing logs..."
    show_mlnx_logs
    exit 1
fi

echo "Installing NVIDIA drivers and components..."
DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    nvidia-open-570 \
    nvlink5-570 \
    nvidia-fabricmanager-570
systemctl enable nvidia-fabricmanager
systemctl enable nvidia-persistenced
