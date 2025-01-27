#!/bin/bash
#K3S_VERSION="v1.23.16%2Bk3s1"
#K3S_VERSION="v1.25.8%2Bk3s1"
K3S_VERSION=$1

if [[ `uname -m` != "x86_64" ]]
ARCH="-arm64"
fi

# K3S_VERSION=`curl https://api.github.com/repos/k3s-io/k3s/releases | jq -r ".[].tag_name" | sort -r`
echo "Downloading k3s binary for $ARCH"
/usr/bin/curl -L https://github.com/k3s-io/k3s/releases/download/$K3S_VERSION/k3s$ARCH -o /usr/local/bin/k3s
/usr/bin/chmod +x /usr/local/bin/k3s

/usr/bin/curl https://get.k3s.io/ > /root/install.sh
/usr/bin/chmod +x /root/install.sh

# Increase pod-count
cat >>  /etc/kubelet.conf <<-EOF
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
maxPods: 4000
EOF
# Increase pod-count
