#!/bin/bash
set -x

LOCAL_REGISTRY_HOST="hauler.local"
SUPER_REGISTRY_HOST="registry.dev.superprotocol.ltd"
SUPER_SCRIPT_DIR="/etc/super"
mkdir -p "$SUPER_SCRIPT_DIR"

mkdir -p "/etc/rancher/rke2"
cat > "/etc/rancher/rke2/config.yaml" <<EOF
kubelet-arg:
  - max-pods=256
disable:
  - rke2-ingress-nginx
  - rke2-metrics-server
cni:
  - cilium
system-default-registry: $LOCAL_REGISTRY_HOST

EOF
cat > "/etc/rancher/rke2/registries.yaml" <<EOF
configs:
  "$SUPER_REGISTRY_HOST:32443":
    tls:
      insecure_skip_verify: true
  "$LOCAL_REGISTRY_HOST:5000":
    tls:
      insecure_skip_verify: true
mirrors:
  "*":
    endpoint:
      - "http://$LOCAL_REGISTRY_HOST:5000"
EOF

mkdir -p "/etc/cni/net.d"
cat > "/etc/cni/net.d/05-cilium.conflist" <<EOF
{
  "cniVersion": "0.3.1",
  "name": "portmap",
  "plugins": [
    {
       "type": "cilium-cni",
       "enable-debug": false,
       "log-file": "/var/run/cilium/cilium-cni.log"
    },
    {
      "type": "portmap",
      "capabilities": {"portMappings": true}
    }
  ]
}
EOF

mkdir -p "/etc/sysctl.d/"
cat > "/etc/sysctl.d/99-zzz-override_cilium.conf" <<EOF
# Disable rp_filter on Cilium interfaces since it may cause mangled packets to be dropped
-net.ipv4.conf.lxc*.rp_filter = 0
-net.ipv4.conf.cilium_*.rp_filter = 0
# The kernel uses max(conf.all, conf.{dev}) as its value, so we need to set .all. to 0 as well.
# Otherwise it will overrule the device specific settings.
net.ipv4.conf.all.rp_filter = 0
EOF

mkdir -p "/etc/rancher/node"
LC_ALL=C tr -dc '[:alpha:][:digit:]' </dev/urandom | head -c 32 > /etc/rancher/node/password

# hauler

# Install rke2
#vRKE2=v1.30.4+rke2r1
vRKE2=v1.30.3-rke2r1

mkdir -p /root/rke2-artifacts
cd /root/rke2-artifacts/
curl -OLs "https://github.com/rancher/rke2/releases/download/${vRKE2}/rke2-images.linux-amd64.tar.zst"
curl -OLs "https://github.com/rancher/rke2/releases/download/${vRKE2}/rke2.linux-amd64.tar.gz"
curl -OLs "https://github.com/rancher/rke2/releases/download/${vRKE2}/sha256sum-amd64.txt"
curl -sfL https://get.rke2.io --output install.sh

# for v1.30.4+rke2r1
SHA_CHECKSUMS=b6545cd7c2d972ba00d8c254e32ca09976311247bb81e1e67d3a79223819196c
# for v1.30.3-rke2r1
SHA_CHECKSUMS=0019dfc4b32d63c1392aa264aed2253c1e0c2fb09216f8e2cc269bbfb8bb49b5
SHA_INSTALL=8d57ffcda9974639891af35a01e9c3c2b8f97ac71075a805d60060064b054492

echo "$SHA_CHECKSUMS sha256sum-amd64.txt" | sha256sum --check
echo "$SHA_INSTALL install.sh" | sha256sum --check

INSTALL_RKE2_ARTIFACT_PATH=/root/rke2-artifacts sh install.sh

cd -
systemctl enable rke2-server.service

mkdir -p "/var/lib/rancher/rke2"
mkdir -p "$SUPER_SCRIPT_DIR/var/lib/rancher/rke2"
#cat > "/etc/rancher/rke2/rke2-pss.yaml" <<EOF
cat > "$SUPER_SCRIPT_DIR/var/lib/rancher/rke2/rke2-pss.yaml" <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: PodSecurity
  configuration:
    apiVersion: pod-security.admission.config.k8s.io/v1beta1
    kind: PodSecurityConfiguration
    defaults:
      enforce: "privileged"
      enforce-version: "latest"
    exemptions:
      usernames: []
      runtimeClasses: []
      namespaces: []
EOF

mkdir -p "$SUPER_SCRIPT_DIR/var/lib/rancher/rke2/agent/etc/containerd/"
cat > "$SUPER_SCRIPT_DIR/var/lib/rancher/rke2/agent/etc/containerd/config.toml.tmpl" <<EOF
version = 2
[plugins."io.containerd.internal.v1.opt"]
  path = "/var/lib/rancher/rke2/agent/containerd"
[plugins."io.containerd.grpc.v1.cri"]
  stream_server_address = "127.0.0.1"
  stream_server_port = "10010"
  enable_selinux = false
  enable_unprivileged_ports = true
  enable_unprivileged_icmp = true
  sandbox_image = "index.docker.io/rancher/mirrored-pause:3.6"
  [plugins."io.containerd.grpc.v1.cri".registry]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."$SUPER_REGISTRY_HOST:32443"]
        endpoint = ["https://$SUPER_REGISTRY_HOST:32443"]
      [plugins."io.containerd.grpc.v1.cri".registry.configs."$SUPER_REGISTRY_HOST:32443".tls]
        insecure_skip_verify = true
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."$LOCAL_REGISTRY_HOST:5000"]
        endpoint = ["https://$LOCAL_REGISTRY_HOST:5000"]
      [plugins."io.containerd.grpc.v1.cri".registry.configs."$LOCAL_REGISTRY_HOST:5000".tls]
        insecure_skip_verify = true
  [plugins."io.containerd.grpc.v1.cri".containerd]
    snapshotter = "overlayfs"
    disable_snapshot_annotations = true
    default_runtime_name = "nvidia"
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
        runtime_type = "io.containerd.runc.v2"
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
          SystemdCgroup = true
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
        privileged_without_host_devices = false
        runtime_engine = ""
        runtime_root = ""
        runtime_type = "io.containerd.runc.v2"
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
          BinaryName = "/opt/nvidia/toolkit/nvidia-container-runtime"
          SystemdCgroup = true
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia-cdi]
        privileged_without_host_devices = false
        runtime_engine = ""
        runtime_root = ""
        runtime_type = "io.containerd.runc.v2"
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia-cdi.options]
          BinaryName = "/opt/nvidia/toolkit/nvidia-container-runtime.cdi"
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia-legacy]
        privileged_without_host_devices = false
        runtime_engine = ""
        runtime_root = ""
        runtime_type = "io.containerd.runc.v2"
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia-legacy.options]
          BinaryName = "/opt/nvidia/toolkit/nvidia-container-runtime.legacy"
EOF

cat >> /usr/local/lib/systemd/system/rke2-server.env <<EOF
RKE2_KUBECONFIG_OUTPUT=/var/lib/rancher/rke2/rke2.yaml
RKE2_POD_SECURITY_ADMISSION_CONFIG_FILE=/var/lib/rancher/rke2/rke2-pss.yaml
EOF

# fix problem with PVC multi-attach https://longhorn.io/kb/troubleshooting-volume-with-multipath/
cat >> /etc/multipath.conf <<EOF
blacklist {
    devnode "^sd[a-z0-9]+"
}
EOF

# copy iscsi configs, cause this partition will be remounted with empty dir
mkdir -p "$SUPER_SCRIPT_DIR/etc/iscsi/"
cp -r "/etc/iscsi/" "$SUPER_SCRIPT_DIR/etc/"

mkdir -p /etc/kubernetes

cat > /etc/resolv.conf <<EOF
nameserver 127.0.0.53
nameserver 1.1.1.1
nameserver 8.8.8.8
options edns0 trust-ad
search .
EOF

cat >> /etc/hosts <<EOF
10.0.2.15	$SUPER_REGISTRY_HOST $LOCAL_REGISTRY_HOST
EOF

# debug
echo "stty cols 180 rows 50" >> /etc/profile

echo "export KUBECONFIG=/var/lib/rancher/rke2/rke2.yaml" >>  /etc/profile
echo "alias k='/var/lib/rancher/rke2/bin/kubectl'" >>  /etc/profile
echo "alias kubectl='/var/lib/rancher/rke2/bin/kubectl'" >>  /etc/profile

sed -i 's|[#]*PasswordAuthentication .*|PasswordAuthentication yes|g' /etc/ssh/sshd_config
sed -i 's|[#]*PermitRootLogin .*|PermitRootLogin yes|g' /etc/ssh/sshd_config
sed -i 's|[#]*KbdInteractiveAuthentication .*|KbdInteractiveAuthentication yes|g' /etc/ssh/sshd_config

### Setup Directories
mkdir -p /opt/hauler/.hauler
cd /opt/hauler

ln -s /opt/hauler/.hauler ~/.hauler

### Download and Install Hauler
vHauler=1.0.8
curl -sfL https://get.hauler.dev | HAULER_VERSION=${vHauler} bash

### Fetch Rancher Airgap Manifests
curl -sfOL https://raw.githubusercontent.com/zackbradys/rancher-airgap/main/hauler/rancher/rancher-airgap-rancher-minimal.yaml
curl -sfOL https://raw.githubusercontent.com/zackbradys/rancher-airgap/main/hauler/longhorn/rancher-airgap-longhorn.yaml
curl -sfOL https://raw.githubusercontent.com/zackbradys/rancher-airgap/main/hauler/cosign/rancher-airgap-cosign.yaml

### Sync Manifests to Hauler Store
hauler store sync --store rancher-store --platform linux/amd64 --files rancher-airgap-rancher-minimal.yaml
hauler store sync --store longhorn-store --platform linux/amd64 --files rancher-airgap-longhorn.yaml
hauler store sync --store extras --files rancher-airgap-cosign.yaml

### Save Hauler Tarballs
hauler store save --store rancher-store --filename rancher-airgap-rancher-minimal.tar.zst
hauler store save --store longhorn-store --filename rancher-airgap-longhorn.tar.zst
hauler store save --store extras --filename rancher-airgap-extras.tar.zst

### Fetch Hauler Binary
curl -sfOL https://github.com/hauler-dev/hauler/releases/download/v${vHauler}/hauler_${vHauler}_linux_amd64.tar.gz

mkdir -p $SUPER_SCRIPT_DIR/opt/hauler
cp *.tar.zst $SUPER_SCRIPT_DIR/opt/hauler/

# curl -sL https://github.com/hauler-dev/hauler/releases/download/v${vHauler}/hauler_${vHauler}_linux_amd64.tar.gz > $SUPER_SCRIPT_DIR/opt/hauler/hauler.tar.gz

#curl -sL https://github.com/hauler-dev/hauler/releases/download/v${vHauler}/hauler_${vHauler}_linux_amd64.tar.gz > hauler.tar.gz
#tar -xf hauler.tar.gz
#chmod 755 hauler && mv hauler /usr/bin/hauler
