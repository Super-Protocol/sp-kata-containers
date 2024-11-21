#!/bin/bash

# Add logging function for stdout only
log() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
}

run_postbuild() {
    local rootfs_dir=$1
    local script_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

    log "INFO" "Starting postbuild script"

    mkdir -p "${rootfs_dir}/etc/netplan"
    log "INFO" "Setting up network configuration"
    cp ${script_dir}/01-netplan.yaml ${rootfs_dir}/etc/netplan
    cp ${script_dir}/fstab ${rootfs_dir}/etc

    if [[ -n "${PROVIDER_CONFIG_DST}" ]]; then
        mkdir -p "${rootfs_dir}/${PROVIDER_CONFIG_DST}"
        echo "sharedfolder   ${PROVIDER_CONFIG_DST}  9p   ro,defaults,_netdev,x-systemd.automount,x-systemd.requires=/run/state   0   0" >> "${rootfs_dir}/etc/fstab"
        sed -i "s|/super-protocol-mounted-directory|${PROVIDER_CONFIG_DST}|g" ${script_dir}/k8s.yaml
    fi

    cp ${script_dir}/tdx-attest.conf ${rootfs_dir}/etc
    cp ${script_dir}/state_disk_mount.service ${rootfs_dir}/etc/systemd/system
    cp ${script_dir}/state_disk_mount.sh ${rootfs_dir}/usr/local/bin
    ln -s /etc/systemd/system/state_disk_mount.service "$rootfs_dir/etc/systemd/system/multi-user.target.wants/state_disk_mount.service"
    chmod +x ${rootfs_dir}/usr/local/bin/state_disk_mount.sh

    cp ${script_dir}/install_tdx_packages.sh ${rootfs_dir}
    cp ${script_dir}/install_nvidia_drivers.sh ${rootfs_dir}

    # Mount necessary filesystems
    log "INFO" "Mounting system filesystems"
    mount -t sysfs -o ro none ${rootfs_dir}/sys
    mount -t proc -o ro none ${rootfs_dir}/proc
    mount -t tmpfs none ${rootfs_dir}/tmp
    mount -o bind,ro /dev ${rootfs_dir}/dev
    mount -t devpts none ${rootfs_dir}/dev/pts

    chroot "$rootfs_dir" /bin/bash "/install_tdx_packages.sh"
    chroot "$rootfs_dir" /bin/bash "/install_nvidia_drivers.sh"
    rm -f "${rootfs_dir}/install_tdx_packages.sh"
    rm -f "${rootfs_dir}/install_nvidia_drivers.sh"

    cp ${script_dir}/nvidia-persistenced.service ${rootfs_dir}/usr/lib/systemd/system/

    # Secure password handling without environment variables
    log "INFO" "Configuring root account security"
    # Generate and set hashed password directly
    chroot $rootfs_dir usermod -p $(openssl rand -base64 32 | openssl passwd -6  -stdin) root
    # Lock root account for additional security
    log "INFO" "Locking root account"
    chroot $rootfs_dir usermod -s /usr/sbin/nologin root

    # Configure SSH security
    if [ -f "${rootfs_dir}/etc/ssh/sshd_config" ]; then
        log "INFO" "Hardening SSH configuration"
        echo "PermitRootLogin no" >> "${rootfs_dir}/etc/ssh/sshd_config"
        echo "MaxAuthTries 3" >> "${rootfs_dir}/etc/ssh/sshd_config"
        echo "PasswordAuthentication no" >> "${rootfs_dir}/etc/ssh/sshd_config"
    fi

    # Configure PAM security
    if [ -f "${rootfs_dir}/etc/pam.d/common-auth" ]; then
        log "INFO" "Configuring PAM security policies"
        echo "auth required pam_tally2.so deny=3 unlock_time=1800 audit silent" >> "${rootfs_dir}/etc/pam.d/common-auth"
    fi

    set -x
    cp "${script_dir}/cert/superprotocol-ca.crt" "${rootfs_dir}/usr/local/share/ca-certificates/superprotocol-ca.crt"
    cp "${script_dir}/cert/ca-initializer-linux" "${rootfs_dir}/usr/local/bin/"
    cp "${script_dir}/cert/superprotocol-certs.sh" "${rootfs_dir}/usr/local/bin/"
    cp "${script_dir}/cert/superprotocol-certs.service" "${rootfs_dir}/etc/systemd/system"
    ln -s /etc/systemd/system/superprotocol-certs.service "$rootfs_dir/etc/systemd/system/multi-user.target.wants/superprotocol-certs.service"
    chroot "${rootfs_dir}" update-ca-certificates --fresh

    cp ${script_dir}/rke.sh ${rootfs_dir}
    chroot "$rootfs_dir" /bin/bash "/rke.sh"
    rm -f ${rootfs_dir}/rke.sh

    mkdir -p "${rootfs_dir}/etc/super/var/lib/rancher/rke2/server/manifests/"
    cp ${script_dir}/k8s.yaml "${rootfs_dir}/etc/super/var/lib/rancher/rke2/server/manifests/"

    cp "${script_dir}/check-config-files.service" "${rootfs_dir}/etc/systemd/system"
    cp "${script_dir}/check-config-files.timer" "${rootfs_dir}/etc/systemd/system"
    cp "${script_dir}/check-config-files.sh" "${rootfs_dir}/usr/local/bin/"
    ln -s /etc/systemd/system/check-config-files.service "$rootfs_dir/etc/systemd/system/multi-user.target.wants/check-config-files.service"
    ln -s /etc/systemd/system/check-config-files.timer "$rootfs_dir/etc/systemd/system/timers.target.wants/check-config-files.timer"

    cp "${script_dir}/local-registry.service" "${rootfs_dir}/etc/systemd/system"
    cp "${script_dir}/local-registry.sh" "${rootfs_dir}/usr/local/bin/"
    chmod +x "${rootfs_dir}/usr/local/bin/local-registry.sh"
    ln -s /etc/systemd/system/local-registry.service "$rootfs_dir/etc/systemd/system/multi-user.target.wants/local-registry.service"

    echo "tty1" > "${rootfs_dir}/etc/securetty"
    cp "${script_dir}/hardening-vm.service" "${rootfs_dir}/etc/systemd/system"
    cp "${script_dir}/hardening-vm.sh" "${rootfs_dir}/usr/local/bin/"
    ln -s /etc/systemd/system/hardening-vm.service "$rootfs_dir/etc/systemd/system/multi-user.target.wants/hardening-vm.service"
    set +x

    # Clean unmounting
    log "INFO" "Performing clean unmount of filesystems"
    for mount_point in "${rootfs_dir}/dev/pts" "${rootfs_dir}/dev" "${rootfs_dir}/tmp" "${rootfs_dir}/proc" "${rootfs_dir}/sys"; do
        if mountpoint -q "$mount_point"; then
            umount "$mount_point" || log "ERROR" "Failed to unmount $mount_point"
        fi
    done

    log "INFO" "Postbuild script completed"
}
