#!/bin/bash

CLUSTER_CIDR=$1
SERVICE_CIDR=$2
CLUSTER_DNS=$3
K3S_FEATURES=$4
DISABLE_KUBE_PROXY=$5

if [ -e "/usr/local/bin/k3s" ]; then
INSTALL_K3S_SKIP_DOWNLOAD=true K3S_KUBECONFIG_MODE="644" INSTALL_K3S_EXEC="--kubelet-arg=config=/etc/kubelet.conf --flannel-backend=none --cluster-cidr=$CLUSTER_CIDR --service-cidr=$SERVICE_CIDR --cluster-dns=$CLUSTER_DNS --disable-network-policy $DISABLE_KUBE_PROXY --disable=$K3S_FEATURES" /root/install.sh
sleep 15
/usr/bin/systemctl, enable, k3s.service
else
## CONTROL
kubeadm init --pod-network-cidr=$CLUSTER_CIDR/16

mkdir -p /root/.kube /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config 
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config 
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config

sleep 5

# generate a join token for Windows
kubeadm token create --print-join-command  > /root/join.sh
fi
