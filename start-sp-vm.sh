#!/bin/bash

# @TODO add example / help
# ./start-sp-vm.sh --use_gpu 8a:00.0 --use_gpu 89:00.0 --cpu 30 --mem 350 --debug on
# @TODO add function for download VM image, kernel, bios, rootfs from github releases
# @TODO check passed gpus with available in host
# @TODO check all required files and dirs are present on host

# Default values
DEFAULT_VM_DISK_SIZE=1000
DEFAULT_CPU_PERCENTAGE=90
DEFAULT_RAM_PERCENTAGE=90
DEFAULT_SSH_PORT=55522
SCRIPT_DIR=$( cd "$( dirname "$0" )" && pwd )
PROVIDER_CONFIG_SRC="$SCRIPT_DIR/provider_config"
ROOT_HASH=$(grep 'Root hash' "$SCRIPT_DIR/root_hash.txt" | awk '{print $3}')
LOG_FILE="$SCRIPT_DIR/vm_log_$(date +"%FT%H%M").log"
BIOS_PATH=/usr/share/qemu/OVMF.fd
DEFAULT_MAC_PREFIX="52:54:00:12:34"
DEFAULT_MAC_SUFFIX="56"
QEMU_COMMAND=" qemu-system-x86_64 "

# Function to get the next available guest-cid and nic_id numbers
get_next_available_id() {
    local base_id=$1
    local check_type=$2
    local max_id=10
    for (( id=$base_id; id<=$max_id; id++ )); do
        if [[ "$check_type" == "guest-cid" ]]; then
            if ! lsof -i :$id &>/dev/null; then
                echo $id
                return
            fi
        elif [[ "$check_type" == "nic_id" ]]; then
            if ! ip link show nic_id$id &>/dev/null; then
                echo $id
                return
            fi
        fi
    done
    echo "No available ID found for $check_type"
    exit 1
}

# Function to generate a unique MAC address
generate_mac_address() {
    local mac_prefix=$1
    local mac_suffix=$2
    for (( i=0; i<100; i++ )); do
        current_mac="$mac_prefix:$mac_suffix"
        if ! ip link show | grep -q "$current_mac"; then
            echo "$current_mac"
            return
        fi
        mac_suffix=$(printf '%x\n' $(( 0x$mac_suffix + 1 )))  # Increment the MAC suffix
    done
    echo "Unable to find an available MAC address."
    exit 1
}

# Collect system info
TOTAL_CPUS=$(nproc)
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
TOTAL_DISK=$(df -h . | awk 'NR==2 {print $4}' | sed 's/G//')
USED_CPUS=0  # Add logic to calculate used CPUs by VM
USED_RAM=0   # Add logic to calculate used RAM by VM
AVAILABLE_GPUS=$(lspci -nnk -d 10de: | grep -E '3D controller' | awk '{print $1}')
USED_GPUS=() # List of used GPUs (to be filled dynamically)
DEBUG_MODE="off"
TDX_SUPPORT=$(lscpu | grep -i tdx)
SEV_SUPPORT=$(lscpu | grep -i sev)

# Default parameters
VM_CPU=$(( TOTAL_CPUS * DEFAULT_CPU_PERCENTAGE / 100 ))
VM_RAM=$(( TOTAL_RAM * DEFAULT_RAM_PERCENTAGE / 100 ))
VM_DISK_SIZE=$DEFAULT_VM_DISK_SIZE
SSH_PORT=$DEFAULT_SSH_PORT
BASE_CID=$(get_next_available_id 3 guest-cid)
BASE_NIC=$(get_next_available_id 0 nic_id)

# Generate a unique MAC address
MAC_ADDRESS=$(generate_mac_address $DEFAULT_MAC_PREFIX $DEFAULT_MAC_SUFFIX)

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --cpu) VM_CPU=$2; shift ;;
        --mem) VM_RAM=$(echo $2 | sed 's/G//'); shift ;;
        --use_gpu) USED_GPUS+=("$2"); shift ;;
        --ssh_port) SSH_PORT=$2; shift ;;
        --debug) DEBUG_MODE=$2; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Collect system information to print
echo "1. Used / total CPUs on host: $VM_CPU / $TOTAL_CPUS"
echo "2. Used RAM for VM / total RAM on host: $VM_RAM GB / $TOTAL_RAM GB"
echo "3. Used GPUs for VM / available GPUs on host: ${USED_GPUS[@]} / $AVAILABLE_GPUS"
echo "4. VM disk size / total available space on host: $VM_DISK_SIZE GB / $TOTAL_DISK GB"
echo "5. Available confidential mode by CPU: ${TDX_SUPPORT:+TDX enabled} ${SEV_SUPPORT:+SEV enabled}"
echo "6. Debug mode: $DEBUG_MODE"
if [[ $DEBUG_MODE == "on" ]]; then
    echo "   SSH Port: $SSH_PORT"
    echo "   MAC Address: $MAC_ADDRESS"
    echo "   Log File: $LOG_FILE"
fi

# Prepare QEMU command with GPU passthrough and chassis increment
CHASSIS=1
for GPU in "${USED_GPUS[@]}"; do
    QEMU_COMMAND+=" -object iommufd,id=iommufd$CHASSIS"
    QEMU_COMMAND+=" -device pcie-root-port,id=pci.$CHASSIS,bus=pcie.0,chassis=$CHASSIS"
    QEMU_COMMAND+=" -device vfio-pci,host=$GPU,bus=pci.$CHASSIS,iommufd=iommufd$CHASSIS"
    QEMU_COMMAND+=" -fw_cfg name=opt/ovmf/X-PciMmio64,straing=262144" # @TODO add only once?
    CHASSIS=$((CHASSIS + 1))
done

# Check for TDX and SEV support and append relevant options
if [[ $TDX_SUPPORT ]]; then
    QEMU_COMMAND+=" -machine q35,kernel_irqchip=split,confidential-guest-support=tdx,memory-backend=ram1,hpet=off"
    QEMU_COMMAND+=" -object tdx-guest,sept-ve-disable=on,id=tdx"
    QEMU_COMMAND+=" -object memory-backend-memfd-private,id=ram1,size=${VM_MEMORY}"
    #QEMU_COMMAND+=" -name process=tdxvm,debug-threads=on" # @TODO needed?
elif [[ $SEV_SUPPORT ]]; then
    QEMU_COMMAND+=" -machine q35,kernel_irqchip=split,confidential-guest-support=sev0" # @TODO check with docs, do we need memory-backend?
    QEMU_COMMAND+=" -object sev-snp-guest,id=sev0,cbitpos=51,reduced-phys-bits=1"
fi

# If debug mode is enabled - Add network devices and enable logging
if [[ $DEBUG_MODE == "on" ]]; then
    QEMU_COMMAND+=" -device virtio-net-pci,netdev=nic_id$BASE_NIC,mac=$MAC_ADDRESS"
    QEMU_COMMAND+=" -netdev user,id=nic_id$BASE_NIC,hostfwd=tcp:127.0.0.1:$SSH_PORT-:22"
    QEMU_COMMAND+=" -chardev stdio,id=mux,mux=on,logfile=$LOG_FILE -monitor chardev:mux -serial chardev:mux"
fi

# Add provider config as directory to VM
if [ -n "${PROVIDER_CONFIG_SRC}" ]; then
    QEMU_COMMAND+=" -fsdev local,security_model=passthrough,id=fsdev0,path=${PROVIDER_CONFIG_SRC}"
    QEMU_COMMAND+=" -device virtio-9p-pci,fsdev=fsdev0,mount_tag=sharedfolder"
fi

# QEMU final launch command
QEMU_COMMAND+=$(cat <<EOF
 -accel kvm \
 -nographic -nodefaults -vga none \
 -cpu host,-kvm-steal-time,pmu=off \
 -bios $BIOS_PATH \
 -m ${VM_RAM}G -smp $VM_CPU \
 -device vhost-vsock-pci,guest-cid=$BASE_CID \
 -drive file=$SCRIPT_DIR/rootfs.img,if=virtio,format=raw \
 -drive file=$SCRIPT_DIR/state.qcow2,if=virtio,format=qcow2 \
 -kernel $SCRIPT_DIR/vmlinuz \
 -append "root=/dev/vda1 console=ttyS0 systemd.log_level=trace systemd.log_target=log rootfs_verity.scheme=dm-verity rootfs_verity.hash=$ROOT_HASH"
EOF
)

# Create VM state disk
qemu-img create -f qcow2 state.qcow2 ${VM_DISK_SIZE}G

echo "Starting QEMU with the following command:"
echo $QEMU_COMMAND
echo "------------"
IFS=' ' read -r -a QEMU_ARGS <<< "$QEMU_COMMAND"
for arg in "${QEMU_ARGS[@]}"; do
    echo " --$arg"
done

sleep 5
eval $QEMU_COMMAND
