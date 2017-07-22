#!/bin/bash

# Add the Kubernetes APT repo and the GPG key associated with it
apt-get update && apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

# Install kubeadm + deps, docker and ceph (for Rook)
apt-get update && apt-get install -y docker.io kubeadm ceph-common

# Install helm
ARCH=${ARCH:-"amd64"}
curl -sSL https://storage.googleapis.com/kubernetes-helm/helm-v2.5.0-linux-${ARCH}.tar.gz | tar -xz -C /usr/local/bin linux-${ARCH}/helm --strip-components=1
curl -sSL https://github.com/containernetworking/plugins/releases/download/v0.6.0-rc1/cni-plugins-${ARCH}-v0.6.0-rc1.tgz | tar -xz -C /opt/cni/bin ./portmap

cat /proc/mounts | awk '{print $2}' | grep '/var/lib/docker' | xargs -r umount
rm -rf /var/lib/docker
sed -e "s|/usr/bin/dockerd|/usr/bin/dockerd -s overlay2|g" -i /lib/systemd/system/docker.service
systemctl daemon-reload
systemctl restart docker
