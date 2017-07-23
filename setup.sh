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
# TODO: Make sure --enable-hostpath-provisioner=true is passed to the controller-manager
kubeadm init --skip-preflight-checks --apiserver-cert-extra-sans api.kubernetesfinland.com

# Use the admin credentials
export KUBECONFIG=/etc/kubernetes/admin.conf

# Make it possible to run normal workloads on your master, assuming you have only one machine
#kubectl taint nodes --all node-role.kubernetes.io/master-

kubectl -n kube-system patch ds kube-proxy -p '{"spec": {"updateStrategy": {"type": "RollingUpdate"}}}'
kubectl -n kube-system set image daemonset/kube-proxy kube-proxy=luxas/kube-proxy:v1.7.0

###### INSTALL INFRASTRUCTURE #######

# Initialize helm and give it permission to modify cluster state
helm init
kubectl -n kube-system create serviceaccount tiller
kubectl -n kube-system patch deploy tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccountName":"tiller"}}}}'
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount kube-system:tiller

# Install Weave Net, and encrypt traffic between hosts
kubectl create secret -n kube-system generic weave-passwd --from-literal=weave-passwd=$(hexdump -n 16 -e '4/4 "%08x" 1 "\n"' /dev/random)
kubectl apply -n kube-system -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')&password-secret=weave-passwd"
# May have to append "&env.IPALLOC_RANGE=172.30.0.0/16" to the above command in order to run Weave on platforms where a 10.0.0.0/8 route already exists on host.

# Install Rook v0.4.0
ROOK_BRANCH=${ROOK_BRANCH:-"release-0.4"}
kubectl apply -f https://raw.githubusercontent.com/rook/rook/${ROOK_BRANCH}/demo/kubernetes/rook-operator.yaml

echo "Waiting for the Rook operator to initialize"
while [[ $(kubectl get cluster; echo $?) == 1 ]]; do sleep 1; done

kubectl apply -f https://raw.githubusercontent.com/rook/rook/${ROOK_BRANCH}/demo/kubernetes/rook-cluster.yaml
kubectl apply -f https://raw.githubusercontent.com/rook/rook/${ROOK_BRANCH}/demo/kubernetes/rook-storageclass.yaml

kubectl apply -f setup/hostpath.yaml

# Deploy the Prometheus operator and an instance in the default namespace so that we can monitor things in the cluster
kubectl apply -f setup/monitoring/prometheus-operator.yaml

echo "Waiting for the Prometheus operator to initialize"
while [[ $(kubectl get prometheus; echo $?) == 1 ]]; do sleep 1; done

kubectl apply -f setup/monitoring/intra-prometheus.yaml

# Mark a worker node to deploy the loadbalancer
kubectl label nodes kubernetesfinland-worker-1 ingress-controller="true"
# Install Traefik on all nodes with the ingress-controller=true label and automatically make Prometheus scrape metrics from Traefik
kubectl apply -f setup/loadbalancing/traefik.yaml


###### INSTALL APPLICATIONS ON TOP #######

# Install Ghost and a backing MariaDB
sed "s|MARIADBPASSWORD|$(hexdump -n 16 -e '4/4 "%08x" 1 "\n"' /dev/random)|g" setup/blog/ghost-values.yaml > setup/blog/ghost-values.tmp.yaml
helm install --name k8s-finland-site -f setup/blog/ghost-values.tmp.yaml ./setup/blog/ghost
rm setup/blog/ghost-values.tmp.yaml

# Make Traefik loadbalance HTTP requests from the internet to the ghost Services in-cluster
kubectl apply -f setup/blog/ghost-ingress.yaml

# Install Slackin so people can join the Slack channel easily
kubectl apply -f setup/blog/slackin.yaml
