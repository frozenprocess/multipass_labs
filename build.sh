#!/bin/bash

CLUSTER_CIDR="172.16.0.0/16"
SERVICE_CIDR="10.43.0.0/16"
CLUSTER_DNS="10.43.0.10"
DIST="k3s"
K3S_VERSION="v1.28.12%2Bk3s1"
KUBE_VERSION="1.32.1"
#K3S_FEATURES_DISABLED="traefik,local-storage,metrics-server,servicelb"
K3S_FEATURES_DISABLED="traefik,local-storage,metrics-server"
#DISABLE_KUBE_PROXY="--disable-kube-proxy"
DISABLE_KUBE_PROXY=""
Help()
{
   # Display Help
   echo "Multipass guru for Calico :) "
   echo "This Guru helps to spin local clusters."
   echo
   echo "options:"
   echo "-h,--help     Print this Help."
   echo "--dist       Which Kubernetes Distrobution(Kube or k3s?), Default: $DIST"
   echo "--cluster_cidr,--ccidr        Cluster CIDR, Default: $CLUSTER_CIDR"
   echo "--service_cidr,--scidr   Service CIDR, Default: $SERVICE_CIDR"
   echo "--cluster_dns,--cdns   Service CIDR, Default: $CLUSTER_DNS"
   echo "--k3s         Version of K3s, Default: $K3S_VERSION"
   echo "--kube        Version of Kubeadm, Default: $KUBE_VERSION"KUBE_VERSION
   echo "V     Print software version and exit."
   echo
}



# Parse command-line options and arguments
OPTIONS=$(getopt -o hc:k: --long help,cidr:,k3s: -n 'script.sh' -- "$@")
if [ $? -ne 0 ]; then
    echo "Usage: script.sh [options]"
    exit 1
fi

# Evaluate the options and their arguments
eval set -- "$OPTIONS"

while true; do
    case "$1" in
        -h|--help)
            # Display Help
            help
            exit;;
        --dist)
            DIST="$2"
            shift 2;;
        --cluster_cidr|--ccidr)
            # Cluster CIDR
            CLUSTER_CIDR="$2"
            shift 2;;
        --service_cidr|--scidr)
            # Cluster CIDR
            CLUSTER_CIDR="$2"
            shift 2;;
        --cluster_dns|--cdns)
            # Cluster dns
            CLUSTER_DNS="$2"
            shift 2;;
        --k3s)
            # K3S Version
            K3S_VERSION="$2"
            shift 2;;
        --kube)
            KUBE_VERSION="$2"
            shift 2;;
        \n)
            help
            exit;;
        --)
            shift
            break;;
    esac
done

rm -rf release certs
mkdir release
mkdir certs

openssl genrsa -out certs/ca.key 2048

openssl req -new -x509 -key certs/ca.key \
  -subj '/CN=private-repo/O=We love Calico/C=US' \
  -days 1024 -out certs/ca.crt

openssl req \
  -newkey rsa:2048 -nodes -sha256 -keyout certs/domain.key \
  -subj '/CN=private-repo/O=We love Calico/C=US' \
  -addext "subjectAltName=DNS:private-repo,DNS:private-repo.multipass,DNS:private-repo.mshome.net,DNS:private-repo,DNS:private-repo.local" \
  -out certs/domain.csr 

openssl x509 -req \
  -CAcreateserial \
  -in certs/domain.csr \
  -CA certs/ca.crt -CAkey certs/ca.key \
  -out certs/domain.crt \
  -days 1024 \
  -sha256 -extensions v3_req -extfile req.conf

if [[ "$(uname -s)" == "Darwin" ]];then
BASE_DECODE="base64 -i"
else
BASE_DECODE="base64 -w 0 "
fi

PREPARE=`$BASE_DECODE prepare.sh`

if [[ "k3s" == $DIST ]];then
DIST="k3s"
DIST_CONTENT=`$BASE_DECODE k3s.sh`
DIST_VERSION=$K3S_VERSION
else
DIST="kubeadm"
DIST_CONTENT=`$BASE_DECODE kube.sh`
DIST_VERSION=$KUBE_VERSION
fi
echo $DIST

CONTROL=`$BASE_DECODE control.sh`
NODE=`$BASE_DECODE node.sh`
REGISTRY_CONFIG=`$BASE_DECODE registry-config.yml`
REGISTRY_CRT=`$BASE_DECODE certs/domain.crt`
REGISTRY_KEY=`$BASE_DECODE certs/domain.key`
SSH_KEY=`cat ${HOME}/.ssh/id_rsa.pub`

CA_CRT=`sed 's/^/      /' certs/ca.crt`

cat > release/control-init.yaml <<-EOF
package_update: true
packages:
  - conntrack
users:
  - default
disable_root: false
ssh_authorized_keys:
  - $SSH_KEY
ca_certs:
  trusted:
    - registry_ca_crt
    - |
$CA_CRT
write_files:
- encoding: b64
  content: $PREPARE
  owner: root:root
  path: /root/prepare.sh
- encoding: b64
  content: $CONTROL
  owner: root:root
  path: /root/control.sh
- encoding: b64
  content: $DIST_CONTENT
  owner: root:root
  path: /root/k3s.sh
runcmd:
  - [ /usr/bin/chmod, +x, /root/prepare.sh ]
  - [ /root/prepare.sh ]
  - [ /usr/bin/chmod, +x, /root/$DIST.sh ]
  - [ /root/$DIST.sh, "$DIST_VERSION" ]
  - [ /usr/bin/chmod, +x, /root/control.sh ]
  - [ /root/control.sh, "$CLUSTER_CIDR", "$SERVICE_CIDR", "$CLUSTER_DNS", "$K3S_FEATURES_DISABLED", "$DISABLE_KUBE_PROXY" ]
  - [ /usr/bin/chown, -R, ubuntu:ubuntu, /home/ubuntu ]

power_state:
  mode: reboot
EOF

cat > release/node-init.yaml <<-EOF
package_update: true
packages:
  - conntrack
users:
  - default
ca_certs:
  trusted:
    - registry_ca_crt
    - |
$CA_CRT

write_files:
- encoding: b64
  content: $PREPARE
  owner: root:root
  path: /root/prepare.sh
- encoding: b64
  content: $NODE
  owner: root:root
  path: /root/node.sh
- encoding: b64
  content: $DIST_CONTENT
  owner: root:root
  path: /root/k3s.sh
ssh_authorized_keys:
  - $SSH_KEY
runcmd:
  - [ /usr/bin/chmod, +x, /root/prepare.sh]
  - [ /root/prepare.sh ]
  - [ /usr/bin/chmod, +x, /root/k3s.sh ]
  - [ /root/k3s.sh, "$DIST_VERSION" ]
  - [ /usr/bin/chmod, +x, /root/node.sh ]
  - [ /root/node.sh ]
  - [ /usr/bin/chown, -R, ubuntu:ubuntu, /home/ubuntu ]

power_state:
  mode: reboot
EOF

cat > release/registry-init.yaml <<-EOF
package_update: true
packages:
  - docker-registry
  - docker.io
users:
  - default
write_files:
- encoding: b64
  content: $PREPARE
  owner: root:root
  path: /root/prepare.sh
- encoding: b64
  content: $REGISTRY_CONFIG
  owner: root:root
  path: /etc/docker/registry/config.yml
- encoding: b64
  content: $REGISTRY_CRT
  owner: root:root
  path: /etc/docker/registry/ca.crt
- encoding: b64
  content: $REGISTRY_KEY
  owner: root:root
  path: /etc/docker/registry/ca.key

disable_root: false
ssh_authorized_keys:
  - $SSH_KEY
runcmd:
  - [ /usr/bin/chmod, +x, /root/prepare.sh ]
  - [ /root/prepare.sh ]
  - [ /usr/sbin/usermod -aG docker ubuntu ]
  - [ /usr/bin/systemctl, enable, docker.service ]
  - [ /usr/bin/systemctl, enable, docker-registry.service ]
EOF
