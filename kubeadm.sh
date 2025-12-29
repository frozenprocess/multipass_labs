#!/bin/bash
set -e
## PREPARE
set -a
source /etc/environment
set +a

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward

if [[ `uname -m` == "x86_64" ]]
then
ARCH="amd64"
else
ARCH="arm64"
fi

curl -OL https://github.com/containerd/containerd/releases/download/v$CONTAINERD/containerd-$CONTAINERD-linux-$ARCH.tar.gz
tar Cxzvf /usr/local containerd-$CONTAINERD-linux-$ARCH.tar.gz

mkdir -p /usr/local/lib/systemd/system/
curl -L https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o /usr/local/lib/systemd/system/containerd.service

systemctl daemon-reload
systemctl enable --now containerd

curl -OL https://github.com/opencontainers/runc/releases/download/v$RUNC/runc.$ARCH
install -m 755 runc.$ARCH /usr/local/sbin/runc

curl -OL https://github.com/containernetworking/plugins/releases/download/v$CNI_PLUGIN/cni-plugins-linux-$ARCH-v$CNI_PLUGIN.tgz
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin cni-plugins-linux-$ARCH-v$CNI_PLUGIN.tgz

systemctl restart containerd

mkdir /etc/containerd
# Cgroup baby
containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/' > /etc/containerd/config.toml

systemctl restart containerd

## Support ubuntu 20.04
DIRECTORY="keyrings"
if [ ! -d "$DIRECTORY" ]; then
    DIRECTORY="trusted.gpg.d"
fi

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/$KUBERNETES_RELEASE_CHANNEL:/v$KUBERNETES_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/$DIRECTORY/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/$DIRECTORY/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/$KUBERNETES_RELEASE_CHANNEL:/v$KUBERNETES_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl jq
sudo apt-mark hold kubelet kubeadm kubectl

# apt-get update
# apt-get install -y kubelet=$KUBERNETES_VERSION-00 kubeadm=$KUBERNETES_VERSION-00 kubectl=$KUBERNETES_VERSION-00 jq

mkdir /root/.kube/

sudo systemctl enable --now kubelet

# IP=`ip route get 1 | awk '{print $(NF-2);exit}'`
# SUFFIX=`dig +short -x $IP | tail -n1 | cut -d. -f2`
