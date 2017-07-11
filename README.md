## Cloud Native Finland

Hi and welcome to the source code for https://cloudnativefinland.com / https://kubernetesfinland.com website!

We are striving to boost the [Kubernetes](https://kubernetes.io) and [CNCF](https://cncf.io) community in Finland
and are currently in the process of organizing a meetup in Helsinki!

### How is this site set up?

A site such as this indeed has to be run on top of Kubernetes and other cool technologies such as Traefik, Weave Net
and Ghost.

The site utilizes the following projects/tools:
 - Kubernetes (installed via kubeadm)
 - Weave Net as the network provider for Kubernetes
 - Helm for installing cool Kubernetes packages
 - Traefik as the loadbalancer to the internal Kubernetes Services
 - Rook for creating an in-cluster persistent storage solution
 - Ghost for the actual site/blog, with MariaDB backing it

#### Installing the tools needed

This assumes running on Ubuntu 16.04+.

```bash
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
```

#### Set up and use your Kubernetes cluster

```bash
#!/bin/bash

# This assumes you're running as root and only have one machine available to run Kubernetes on.

# Start your Kubernetes master
kubeadm init

# Use the admin credentials
export KUBECONFIG=/etc/kubernetes/admin.conf

# Make it possible to run normal workloads on your master, assuming you have only one machine
kubectl taint nodes --all node-role.kubernetes.io/master-

# Initialize helm and give it permission to modify cluster state
helm init
kubectl -n kube-system create serviceaccount tiller
kubectl -n kube-system patch deploy tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccountName":"tiller"}}}}'
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount kube-system:tiller

# Install Weave Net
kubectl apply -n kube-system -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')&env.IPALLOC_RANGE=172.30.0.0/16"

# Install Rook v0.4.0
ROOK_BRANCH=${ROOK_BRANCH:-"release-0.4"}
kubectl apply -f https://raw.githubusercontent.com/rook/rook/${ROOK_BRANCH}/demo/kubernetes/rook-operator.yaml

echo "Waiting for the Rook operator to initialize"
while [[ $(kubectl get cluster; echo $?) == 1 ]]; do sleep 1; done

kubectl apply -f https://raw.githubusercontent.com/rook/rook/${ROOK_BRANCH}/demo/kubernetes/rook-cluster.yaml
kubectl apply -f https://raw.githubusercontent.com/rook/rook/${ROOK_BRANCH}/demo/kubernetes/rook-storageclass.yaml

# Install Ghost and MariaDB
helm install --name k8s-finland-site -f setup/ghost.yaml stable/ghost

# Mark the master node to deploy the loadbalancer
kubectl label nodes --all ingress-controller="true"
# Install Traefik
kubectl apply -f setup/traefik.yaml

# Make Traefik loadbalance HTTP requests from the internet to the ghost Services in-cluster
kubectl apply -f setup/ghost-ingress.yaml
```

### Roadmap

See [ROADMAP.md](ROADMAP.md)

### License

MIT