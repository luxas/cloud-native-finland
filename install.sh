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
curl -sSL https://storage.googleapis.com/kubernetes-helm/helm-v2.5.0-linux-amd64.tar.gz | tar -xz -C /usr/local/bin linux-amd64/helm --strip-components=1
