#!/bin/bash
set -x

mkdir -p "/etc/rancher/rke2"
cat > "/etc/rancher/rke2/config.yaml" <<EOF
kubelet-arg:
  - max-pods=256
disable:
  - rke2-ingress-nginx
  - rke2-metrics-server
cni:
# - none
# - cilium
  - flannel
EOF
cat > "/etc/rancher/rke2/registries.yaml" <<EOF
configs:
  "registry.superprotocol.ltd:32443":
    tls:
      insecure_skip_verify: true
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


mkdir -p "/etc/rancher/node"
LC_ALL=C tr -dc '[:alpha:][:digit:]' </dev/urandom | head -c 32 > /etc/rancher/node/password

curl -sfL https://get.rke2.io | INSTALL_RKE2_CHANNEL="v1.28.11+rke2r1" sh -
systemctl enable rke2-server.service && systemctl start rke2-server.service

mkdir -p "/etc/rancher/rke2/"
mkdir -p "/var/lib/rancher/rke2"

#cat > "/etc/rancher/rke2/rke2-pss.yaml" <<EOF
cat > "/var/lib/rancher/rke2/rke2-pss.yaml" <<EOF
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

cat >> /usr/local/lib/systemd/system/rke2-server.env <<EOF
RKE2_KUBECONFIG_OUTPUT=/var/lib/rancher/rke2/rke2.yaml
EOF

# debug
echo "stty cols 180 rows 50" >> /etc/profile

#update-alternatives --set iptables /usr/sbin/iptables-legacy

cat /etc/rancher/rke2/rke2-pss.yaml

echo "export KUBECONFIG=/var/lib/rancher/rke2/rke2.yaml" >>  /etc/profile
echo "alias k='/var/lib/rancher/rke2/bin/kubectl'" >>  /etc/profile
echo "alias kubectl='/var/lib/rancher/rke2/bin/kubectl'" >>  /etc/profile

sed -i 's|[#]*PasswordAuthentication .*|PasswordAuthentication yes|g' /etc/ssh/sshd_config
sed -i 's|[#]*PermitRootLogin .*|PermitRootLogin yes|g' /etc/ssh/sshd_config
sed -i 's|[#]*KbdInteractiveAuthentication .*|KbdInteractiveAuthentication yes|g' /etc/ssh/sshd_config
