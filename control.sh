#!/bin/bash

set -a
source /etc/environment
set +a

if [ -e "/usr/local/bin/k3s" ]; then
INSTALL_K3S_SKIP_DOWNLOAD=true K3S_KUBECONFIG_MODE="644" INSTALL_K3S_EXEC="--kubelet-arg=config=/etc/kubelet.conf --flannel-backend=none --cluster-cidr=$CLUSTER_CIDR --service-cidr=$SERVICE_CIDR --cluster-dns=$CLUSTER_DNS --disable-network-policy $DISABLE_KUBE_PROXY --disable=$K3S_FEATURES_DISABLED" /root/k3s-install.sh
sleep 15
/usr/bin/systemctl, enable, k3s.service
else
sleep 10
echo "Initializing kubeadm control plane node"
KUBERNETES_VERSION=$(/usr/bin/kubeadm version -o json | jq -r '.clientVersion.gitVersion')
## CONTROL
/usr/bin/kubeadm init --pod-network-cidr=$CLUSTER_CIDR --kubernetes-version=$KUBERNETES_VERSION

mkdir -p /root/.kube /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config 
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config 
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config

sleep 5

# generate a join token for Windows
/usr/bin/kubeadm token create --print-join-command  > /root/join.sh
chmod +x /root/join.sh
fi
