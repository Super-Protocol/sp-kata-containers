#/bin/bash

STATE_DISK_SIZE=100
VM_MEMORY=16
VM_CPU=4

export DISTRO="ubuntu"
SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
export ROOTFS_DIR="${SCRIPT_DIR}/build/rootfs"

KERNEL_NAME=nvidia-gpu-confidential

pushd "${SCRIPT_DIR}/tools/packaging/kata-deploy/local-build"
./kata-deploy-binaries-in-docker.sh --build="kernel-${KERNEL_NAME}"
popd

rm -rf "${SCRIPT_DIR}/build"
mkdir -p "${SCRIPT_DIR}/build/rootfs/opt/deb"

pushd "${SCRIPT_DIR}/build/rootfs/opt/deb"
find "${SCRIPT_DIR}/tools/packaging/kata-deploy/local-build/build/kernel-${KERNEL_NAME}/builddir/" -name "*.deb" -exec cp {} . \;
mkdir nvidia
cd nvidia
wget "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb"
popd

pushd "${SCRIPT_DIR}/tools/osbuilder/rootfs-builder"
script -fec 'sudo -E USE_DOCKER=true MEASURED_ROOTFS=yes EXTRA_PKGS="openssh-server netplan.io ubuntu-minimal dmsetup ca-certificates" ./rootfs.sh "${DISTRO}"'
popd

pushd "${SCRIPT_DIR}/tools/osbuilder/image-builder"
script -fec 'sudo -E USE_DOCKER=true MEASURED_ROOTFS=yes ./image_builder.sh -r 1000 "${ROOTFS_DIR}"'
popd

cp "${SCRIPT_DIR}/tools/osbuilder/image-builder/kata-containers.img" "${SCRIPT_DIR}/build/rootfs.img"
cp "${SCRIPT_DIR}/tools/osbuilder/image-builder/root_hash.txt" "${SCRIPT_DIR}/build/"
cp -L "${SCRIPT_DIR}/tools/packaging/kata-deploy/local-build/build/kernel-${KERNEL_NAME}/destdir/opt/kata/share/kata-containers/vmlinuz-${KERNEL_NAME}.container" "${SCRIPT_DIR}/build/vmlinuz"

pushd "${SCRIPT_DIR}/build"
qemu-img create -f qcow2 state.qcow2 ${STATE_DISK_SIZE}G

ROOT_HASH=$(grep 'Root hash' root_hash.txt | awk '{print $3}')

QEMU_COMMAND="qemu-system-x86_64 \
    -drive file=rootfs.img,if=virtio,format=raw \
    -drive file=state.qcow2,if=virtio,format=qcow2 \
    -m ${VM_MEMORY}G \
    -smp ${VM_CPU} \
    -nographic \
    -kernel vmlinuz \
    -append \"root=/dev/vda1 console=ttyS0 systemd.log_level=trace systemd.log_target=log rootfs_verity.scheme=dm-verity rootfs_verity.hash=${ROOT_HASH}\" \
    -device virtio-net-pci,netdev=nic0_td -netdev user,id=nic0_td,hostfwd=tcp::2222-:22"

echo "${QEMU_COMMAND}" > run_vm.sh
chmod +x run_vm.sh
popd