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
