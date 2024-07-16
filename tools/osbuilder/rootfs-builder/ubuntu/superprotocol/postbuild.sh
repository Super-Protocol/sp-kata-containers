run_postbuild() {
	local rootfs_dir=$1
	local script_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

	mkdir -p "${rootfs_dir}/etc/netplan"
	cp ${script_dir}/01-netplan.yaml ${rootfs_dir}/etc/netplan

	cp ${script_dir}/fstab ${rootfs_dir}/etc

	cp ${script_dir}/state_disk_mount.service ${rootfs_dir}/etc/systemd/system
	cp ${script_dir}/state_disk_mount.sh ${rootfs_dir}/usr/local/bin
	ln -s /etc/systemd/system/state_disk_mount.service "$rootfs_dir/etc/systemd/system/multi-user.target.wants/state_disk_mount.service"
	chmod +x ${rootfs_dir}/usr/local/bin/state_disk_mount.sh

	cp ${script_dir}/install_nvidia_drivers.sh ${rootfs_dir}

	mount -t sysfs -o ro none ${rootfs_dir}/sys
	mount -t proc -o ro none ${rootfs_dir}/proc
	mount -t tmpfs none ${rootfs_dir}/tmp
	mount -o bind,ro /dev ${rootfs_dir}/dev
	mount -t devpts none ${rootfs_dir}/dev/pts

	chroot "$rootfs_dir" /bin/bash "/install_nvidia_drivers.sh"
	rm -f ${rootfs_dir}/install_nvidia_drivers.sh
	cp ${script_dir}/nvidia-persistenced.service ${rootfs_dir}/usr/lib/systemd/system/

	echo 'root:123456' | chroot $rootfs_dir chpasswd

	set -x
	cp ${script_dir}/rke.sh ${rootfs_dir}
	chroot "$rootfs_dir" /bin/bash "/rke.sh"
	rm -f ${rootfs_dir}/rke.sh
	set +x

	umount ${rootfs_dir}/dev/pts
	umount ${rootfs_dir}/dev
	umount ${rootfs_dir}/tmp
	umount ${rootfs_dir}/proc
	umount ${rootfs_dir}/sys
}
