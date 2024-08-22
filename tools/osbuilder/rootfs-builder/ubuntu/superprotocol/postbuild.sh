run_postbuild() {
	local rootfs_dir=$1
	local script_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
	# rm ssh keys and generate it in runtime
	find "${rootfs_dir}/etc/ssh" -name "ssh_host_*" -exec rm -v {} +
	sed -i -e 's|#HostKey /etc/ssh/ssh_host_rsa_key|HostKey /etc/ssh/keys/ssh_host_rsa_key|' \
	   -e 's|#HostKey /etc/ssh/ssh_host_ecdsa_key|HostKey /etc/ssh/keys/ssh_host_ecdsa_key|' \
	   -e 's|#HostKey /etc/ssh/ssh_host_ed25519_key|HostKey /etc/ssh/keys/ssh_host_ed25519_key|' \
	   "${rootfs_dir}/etc/ssh/sshd_config"

	mkdir -p "${rootfs_dir}/etc/ssh/keys"
	cp ${script_dir}/gen_ssh_keys.sh "${rootfs_dir}/etc/ssh"
	sed -i '/ExecStartPre=/i ExecStartPre=/etc/ssh/gen_ssh_keys.sh' "${rootfs_dir}/usr/lib/systemd/system/ssh.service"

	# rm initiatorname.iscsi and generate it in runtime
	rm -f "${rootfs_dir}/etc/iscsi/initiatorname.iscsi"

	mkdir -p "${rootfs_dir}/etc/netplan"
	cp ${script_dir}/01-netplan.yaml ${rootfs_dir}/etc/netplan

	cp ${script_dir}/fstab ${rootfs_dir}/etc

	if [[ -n "${PROVIDER_CONFIG_DST}" ]]; then
		mkdir -p "${rootfs_dir}/${PROVIDER_CONFIG_DST}"
		echo "sharedfolder   ${PROVIDER_CONFIG_DST}  9p   ro,defaults,_netdev   0   0" >> "${rootfs_dir}/etc/fstab"
	fi

	cp ${script_dir}/tdx-attest.conf ${rootfs_dir}/etc

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
	mkdir -p "${rootfs_dir}/etc/super/var/lib/rancher/rke2/server/manifests/"
	cp ${script_dir}/k8s-infra.yaml "${rootfs_dir}/etc/super/var/lib/rancher/rke2/server/manifests/"

	cp "${script_dir}/check-config-files.service" "${rootfs_dir}/etc/systemd/system"
	cp "${script_dir}/check-config-files.timer" "${rootfs_dir}/etc/systemd/system"
	cp "${script_dir}/check-config-files.sh" "${rootfs_dir}/usr/local/bin/"
	ln -s /etc/systemd/system/check-config-files.service "$rootfs_dir/etc/systemd/system/multi-user.target.wants/check-config-files.service"
	ln -s /etc/systemd/system/check-config-files.timer "$rootfs_dir/etc/systemd/system/timers.target.wants/check-config-files.timer"

	set +x

	umount ${rootfs_dir}/dev/pts
	umount ${rootfs_dir}/dev
	umount ${rootfs_dir}/tmp
	umount ${rootfs_dir}/proc
	umount ${rootfs_dir}/sys
}
