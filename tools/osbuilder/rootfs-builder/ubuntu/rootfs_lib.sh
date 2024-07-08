# Copyright (c) 2018 Yash Jain, 2022 IBM Corp.
#
# SPDX-License-Identifier: Apache-2.0

build_dbus() {
	local rootfs_dir=$1
	ln -sf /lib/systemd/system/dbus.service $rootfs_dir/etc/systemd/system/dbus.service
	ln -sf /lib/systemd/system/dbus.socket $rootfs_dir/etc/systemd/system/dbus.socket
}

build_rootfs() {
	local rootfs_dir=$1
	local multistrap_conf=multistrap.conf

	# For simplicity's sake, use multistrap for foreign and native bootstraps.
	cat > "$multistrap_conf" << EOF
[General]
aptsources=Ubuntu Ubuntu-updates
bootstrap=Ubuntu


[Ubuntu-updates]
source=$REPO_URL
keyring=ubuntu-keyring
suite=$UBUNTU_CODENAME-updates

[Ubuntu]
source=$REPO_URL
suite=$UBUNTU_CODENAME
packages=$PACKAGES $EXTRA_PKGS openssh-server netplan.io ubuntu-minimal dmsetup

EOF

	if [ "${CONFIDENTIAL_GUEST}" == "yes" ] && [ "${DEB_ARCH}" == "amd64" ]; then
		mkdir -p $rootfs_dir/etc/apt/trusted.gpg.d/
		curl -fsSL https://download.01.org/intel-sgx/sgx_repo/ubuntu/intel-sgx-deb.key |
			gpg --dearmour -o $rootfs_dir/etc/apt/trusted.gpg.d/intel-sgx-deb.gpg
		sed -i -e "s/bootstrap=Ubuntu/bootstrap=Ubuntu intel-sgx/" $multistrap_conf
		cat >> $multistrap_conf << EOF

[intel-sgx]
source=https://download.01.org/intel-sgx/sgx_repo/ubuntu
suite=$UBUNTU_CODENAME
packages=libtdx-attest=1.20\*
EOF
	fi

	if ! multistrap -a "$DEB_ARCH" -d "$rootfs_dir" -f "$multistrap_conf"; then
		build_dbus $rootfs_dir
	fi
	rm -rf "$rootfs_dir/var/run"
	ln -s /run "$rootfs_dir/var/run"
	cp --remove-destination /etc/resolv.conf "$rootfs_dir/etc"

	local dir="$rootfs_dir/etc/ssl/certs"
	mkdir -p "$dir"
	cp --remove-destination /etc/ssl/certs/ca-certificates.crt "$dir"

	# Reduce image size and memory footprint by removing unnecessary files and directories.
	rm -rf $rootfs_dir/usr/share/{bash-completion,bug,doc,info,lintian,locale,man,menu,misc,pixmaps,terminfo,zsh}

	# Minimal set of device nodes needed when AGENT_INIT=yes so that the
	# kernel can properly setup stdout/stdin/stderr for us
	pushd $rootfs_dir/dev
	MAKEDEV -v console tty ttyS null zero fd
	popd

	mkdir -p "$rootfs_dir/etc/netplan"
	cat > "$rootfs_dir/etc/netplan/01-network-manager-all.yaml" << EOF
# Let NetworkManager manage all devices on this system
network:
  version: 2
  renderer: networkd
  ethernets:
    ens3:
      dhcp4: yes

EOF

	cat > "$rootfs_dir/etc/fstab" << EOF
/dev/mapper/crypto       /run/state         ext4    defaults,x-systemd.makefs,x-mount.mkdir    0    1
/run/state/var           /var               none    defaults,bind,x-mount.mkdir                0    0
#/run/state/kubernetes    /etc/kubernetes    none    defaults,bind,x-mount.mkdir                0    0
#/run/state/etccni        /etc/cni/          none    defaults,bind,x-mount.mkdir                0    0
/run/state/opt           /opt               none    defaults,bind,x-mount.mkdir                0    0
EOF


	local unitFile="/etc/systemd/system/state_disk_mount.service"
	local scriptFile="/usr/local/bin/state_disk_mount.sh"
	mkdir -p `dirname "$rootfs_dir/$unitFile"`

	cat > "$rootfs_dir/$unitFile" << EOF
[Unit]
Description=Create LUKS partition
Before=local-fs.target cryptsetup.target
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=$scriptFile

[Install]
WantedBy=multi-user.target
EOF

	ln -s $unitFile "$rootfs_dir/etc/systemd/system/multi-user.target.wants/state_disk_mount.service"

	mkdir -p `dirname "$rootfs_dir/scriptFile"`

	cat > "$rootfs_dir/$scriptFile" << EOF
#!/bin/bash
wipefs -a /dev/vdb
RANDOM_KEY=$(dd if=/dev/urandom bs=1 count=32 2>/dev/null | base64)
echo "\$RANDOM_KEY" | cryptsetup luksFormat /dev/vdb --batch-mode
echo "\$RANDOM_KEY" | cryptsetup luksOpen /dev/vdb crypto
mkfs.ext4 /dev/mapper/crypto
EOF

	chmod +x $rootfs_dir/$scriptFile
	local UPDATE_LIBC_SCRIPT="update_libc6.sh"

		cat > "$rootfs_dir/$UPDATE_LIBC_SCRIPT" << EOF
mkdir -p /var/cache/apt/archives/partial
mkdir -p /var/log/apt
dpkg --configure -a

apt install libc6 --no-install-recommends -y

rm -rf /var/log/apt
rm -rf /var/cache/apt/archives/partial
EOF
	chroot "$rootfs_dir" /bin/bash "/$UPDATE_LIBC_SCRIPT"
	chroot "$rootfs_dir" /bin/bash -c "rm -f /$UPDATE_LIBC_SCRIPT"
	echo 'root:123456' | chroot $rootfs_dir chpasswd
}
