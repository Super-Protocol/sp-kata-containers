#/bin/bash

export distro="ubuntu" # example
export ROOTFS_DIR="$(realpath ./tools/osbuilder/rootfs-builder/rootfs)"
SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"

sudo rm -rf "${ROOTFS_DIR}"
pushd "${SCRIPT_DIR}/tools/osbuilder/rootfs-builder"
script -fec 'sudo -E USE_DOCKER=true MEASURED_ROOTFS=yes ./rootfs.sh "${distro}"'
popd

pushd "${SCRIPT_DIR}/tools/osbuilder/image-builder"
script -fec 'sudo -E USE_DOCKER=true MEASURED_ROOTFS=yes ./image_builder.sh "${ROOTFS_DIR}"'
popd

pushd "${SCRIPT_DIR}/tools/packaging/kata-deploy/local-build"
./kata-deploy-binaries-in-docker.sh --build=kernel-confidential
popd