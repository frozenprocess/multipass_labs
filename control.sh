#!/bin/bash

CLUSTER_CIDR=$1
SERVICE_CIDR=$2
CLUSTER_DNS=$3
K3S_FEATURES=$4
DISABLE_KUBE_PROXY=$5
# Increase pod-count
cat >>  /etc/kubelet.conf <<-EOF
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
maxPods: 4000
EOF
# Increase pod-count

INSTALL_K3S_SKIP_DOWNLOAD=true K3S_KUBECONFIG_MODE="644" INSTALL_K3S_EXEC="--kubelet-arg=config=/etc/kubelet.conf --flannel-backend=none --cluster-cidr=$CLUSTER_CIDR --service-cidr=$SERVICE_CIDR --cluster-dns=$CLUSTER_DNS --disable-network-policy $DISABLE_KUBE_PROXY --disable=traefik,local-storage,metrics-server,servicelb" /root/install.sh
