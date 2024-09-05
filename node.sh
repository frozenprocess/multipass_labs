#!/bin/bash

# Multi cluster
NODE_NAME=`hostname | sed -e 's/\(.*\?node\).*\?/\1/'`
if [[ "$NODE_NAME" != "node" ]];then
    CONTROL_NAME=`hostname | sed -e 's/\(.*\?\)node.*\?/\1control/'`
else
    CONTROL_NAME="control"
fi
CONTROL_IP=""
if [[ $CONTROL_IP == "" && "$(dig +short $CONTROL_NAME.local)" != "" ]];then
CONTROL_NAME=$CONTROL_NAME.local
CONTROL_IP=`dig +short $CONTROL_NAME`
elif [[ $CONTROL_IP == "" && "$(dig +short $CONTROL_NAME.mshome.net)" != "" ]];then
CONTROL_NAME=$CONTROL_NAME.mshome.net
CONTROL_IP=`dig +short $CONTROL_NAME`
elif [[ $CONTROL_IP == "" &&  "$(dig +short $CONTROL_NAME.multipass)" != "" ]];then
CONTROL_NAME=$CONTROL_NAME.multipass
CONTROL_IP=`dig +short $CONTROL_NAME`
fi
# Multi cluster

TRIES=0
while [[ $(curl --write-out '%{http_code}' --silent --output /dev/null $CONTROL_IP:6443) != "400" ]]
do
    if [[ $TRIES -eq 60 ]]; then
        echo "Failed to find the k3s server"
        exit 1 
    fi
    echo "Waiting for $CONTROL_IP"
    sleep 1
    TRIES=$(( TRIES + 1 ))
done

# Increase pod-count
cat >>  /etc/kubelet.conf <<-EOF
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
maxPods: 4000
EOF
# Increase pod-count

echo "Agents"
/usr/bin/scp -i "/etc/ssh/ssh_host_rsa_key" -o StrictHostKeyChecking=no root@$CONTROL_IP:/var/lib/rancher/k3s/server/node-token /root/node-token 
K3S_TOKEN=`cat /root/node-token` K3S_URL="https://$CONTROL_IP:6443" INSTALL_K3S_EXEC="--kubelet-arg=config=/etc/kubelet.conf" INSTALL_K3S_SKIP_DOWNLOAD=true /root/install.sh
