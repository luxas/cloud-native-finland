#!/bin/bash

# This assumes you're running as root and only have one machine available to run Kubernetes on.

###### CREATE KUBERNETES CLUSTERS #######

# Make Weave capable of using the portmap plugin
mkdir -p /etc/cni/net.d/
cat > /etc/cni/net.d/10-mynet.conflist <<EOF
{
    "cniVersion": "0.3.0",
    "name": "mynet",
    "plugins": [
        {
            "name": "weave",
            "type": "weave-net",
            "hairpinMode": true
        },
        {
            "type": "portmap",
            "capabilities": {"portMappings": true},
            "snat": true
        }
    ]
}
EOF

# Start your Kubernetes master
systemctl start kubelet
kubeadm init --skip-preflight-checks

# Use the admin credentials
export KUBECONFIG=/etc/kubernetes/admin.conf

# Make it possible to run normal workloads on your master, assuming you have only one machine
kubectl taint nodes --all node-role.kubernetes.io/master-

###### INSTALL INFRASTRUCTURE #######

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

# Deploy the Prometheus operator and an instance in the default namespace so that we can monitor things in the cluster
kubectl apply -f setup/prometheus-operator.yaml
kubectl apply -f setup/intra-prometheus.yaml

# Mark the master node to deploy the loadbalancer
kubectl label nodes --all ingress-controller="true"
# Install Traefik on all nodes with the ingress-controller=true label and automatically make Prometheus scrape metrics from Traefik
kubectl apply -f setup/traefik.yaml


###### INSTALL APPLICATIONS ON TOP #######

# Install Ghost and a backing MariaDB
helm install --name k8s-finland-site -f setup/ghost.yaml stable/ghost

# Make Traefik loadbalance HTTP requests from the internet to the ghost Services in-cluster
kubectl apply -f setup/ghost-ingress.yaml

# Install Slackin so people can join the Slack channel easily
kubectl apply -f setup/slackin.yaml
