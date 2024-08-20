#!/bin/bash

CLUSTER_CIDR="172.16.0.0/16"
SERVICE_CIDR="10.43.0.0/16"
CLUSTER_DNS="10.43.0.10"
K3S_VERSION="v1.28.12%2Bk3s1"
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
   echo "--cluster_cidr,--ccidr        Cluster CIDR, Default: $CLUSTER_CIDR"
   echo "--service_cidr,--scidr   Service CIDR, Default: $SERVICE_CIDR"
   echo "--cluster_dns,--cdns   Service CIDR, Default: $CLUSTER_DNS"
   echo "--k3s         Version of K3s, Default: $K3S_VERSION"
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
        \n)
            help
            exit;;
        --)
            shift
            break;;
    esac
done

rm -rf release
mkdir release

if [[ "$(uname -s)" == "Darwin" ]];then
BASE_DECODE="base64 -i"
else
BASE_DECODE="base64 -w 0 "
fi

PREPARE=`$BASE_DECODE prepare.sh`
CONTROL=`$BASE_DECODE control.sh`
NODE=`$BASE_DECODE node.sh`
REGISTRY_CONFIG=`$BASE_DECODE registry-config.yml`
REGISTRY_CRT=`$BASE_DECODE certs/domain.crt`
REGISTRY_KEY=`$BASE_DECODE certs/domain.key`

CA_CRT=`sed 's/^/      /' certs/ca.crt`

cat > release/control-init.yaml <<-EOF
package_update: true
packages:
  - conntrack
users:
  - default
disable_root: false
ssh_authorized_keys:
  - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCvW2dRLu0PLQeQ5q5X76RaPvh8/lhhTzucdOizgzJfbUClve4KVCivtB1/S0rX6uuZL6TZhtRDrB1bVGAkwnt6zTT/irQ1ly1AseLAGIdA+03ikQ4gD1hL+MPURko4O9qWyDpBzPtjinRkXYTPdDe3g5jj1CZMI8uw+oOwdxf/9efeEfiQZ+pZuqgtEJttxWx3NrLqiyZhiciSVoRxyXkOltMdovzNeeeRB0KkFKhjSWhjTW0QRJ19ZsDtH3lxChQd7YFfTtYL0oe3ZkRINzHwfr1vzTVaolWTF70H4LWFaTZpmFWZ+WmmXNriUHwov2TBsCYRMAJkM72PAi8WmtWR calico@cloud
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

runcmd:
  - [ /usr/bin/chmod, +x, /root/prepare.sh ]
  - [ /root/prepare.sh, "$K3S_VERSION" ]
  - [ /usr/bin/chmod, +x, /root/control.sh ]
  - [ /root/control.sh, "$CLUSTER_CIDR", "$SERVICE_CIDR", "$CLUSTER_DNS", "$K3S_FEATURES_DISABLED", "$DISABLE_KUBE_PROXY" ]
  - [ /usr/bin/chown, -R, ubuntu:ubuntu, /home/ubuntu ]
  - [ /usr/bin/systemctl, enable, k3s.service ]

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
ssh_keys:
  rsa_private: |
    -----BEGIN RSA PRIVATE KEY-----
    MIIEowIBAAKCAQEAr1tnUS7tDy0HkOauV++kWj74fP5YYU87nHTos4MyX21Apb3u
    ClQor7Qdf0tK1+rrmS+k2YbUQ6wdW1RgJMJ7es00/4q0NZctQLHiwBiHQPtN4pEO
    IA9YS/jD1EZKODvalsg6Qcz7Y4p0ZF2Ez3Q3t4OY49QmTCPLsPqDsHcX//Xn3hH4
    kGfqWbqoLRCbbcVsdzay6osmYYnIklaEccl5DpbTHaL8zXnnkQdCpBSoY0loY01t
    EESdfWbA7R95cQoUHe2BX07WC9KHt2ZESDcx8H69b801WqJVkxe9B+C1hWk2aZhV
    mflpplza4lB8KL9kwbAmETACZDO9jwIvFprVkQIDAQABAoIBAGGevNGREh+UrdWY
    1g3WNuSWkbbj0Ue62DCtVK46p1xAcfDS3yWY3F2UI6etvqic+zN4NolyadCSjHU/
    b5aHPj6K5qosCU6cLnEJlnXiMcmXHTC4F+j5IeqJPlt6Fe9gQrwWE3h2KKytc0Y8
    Waczx6C9/es3O2q/srF/hLhEVHQFAUzVQ0VAYdHZUcWgrTRtCi+etXaYssXLbuH/
    R0UVb4qctEHRbE9LwLOG8u7o+xC9xYnmMUKAKgyEwwYIR5F1kR3Ebl/cx10owfqV
    YhF7V3hbpAbNUdsdhG/Wv3Q3pRFzz3hRGQpfFPG1PINpf3j5oGTbMzdxuT6ddbq+
    1wNsWcECgYEA3HXqkoRx5bSvIMhrOQJmrXjxo5ecWfa8sLohJJYkka9G3TprA4fy
    9p1IbPgkzDO0RQmCxKQt3Z7OC5mk1owevpF+sJEEFYKhRdOoS8u3VONp6vWUikVc
    hdpeWAOWOc7tiYMyew6+NprBNF2YbgnRnNXdErfGYGt4p2+Yn19+jIUCgYEAy6Ah
    OR8pTaGu2p6WYHJtYPa90zHwVSSBcpNREVoNrIPo/YEOZDPCnKTEX+rHoEdSS1lC
    n2E3hytP7vv/sPGRz2R7h2+2Off47smdt4wJ6zoioOTPjWnCUfix4Kjay5WGswSJ
    tsMVe2WTaUV/bG/d23du4CLmVHnZOmJK0Ml4iJ0CgYBCBgJhLM8bdvg3vi32XdS4
    QQ9E6gPGIZGy75s7ZMfA5Zg4auVfolhOKR5mnA4RJa7oOgfysiSWSZf1e2cVZdNT
    SSmC4XsyofOAgPnW8USPZKf02OVKX6ls4M/+VdyopWMYGrWEiw7GNaSE9T7QPZqL
    +LSDhYwgli8FHfO8TxIMLQKBgQCv5frtIjsGwcWPOvGCDTbpTRw7pWcL1cYw2Itu
    JtGrFiQdYO+ypXfW4wp0JRcfIJ05U7kWft99129sbam6C2O+uPlwzJKozsnuVKH2
    nXUwCv9A54dXjGV9dA0MmjCvLtK2MBRamXkkKGHHzW4+mQAYhrpzyhIYJU3+fkxM
    wc1qjQKBgF7erwUBI5zt+vPcurh/pANDWuEOz1zqBr3svqXytI8UvySuHP9qfHY0
    JLdAyiMNRolMOEVe7umTbB95DifK7DqK2bTw9jrtUdOJ18G5cTf3+pv8NZKCg0B8
    56E90uQJS9aJ/qVZiubWiZpFuIX2tqjulqpp9aN3NbA/Uv8YJa78
    -----END RSA PRIVATE KEY-----

  rsa_public: ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCvW2dRLu0PLQeQ5q5X76RaPvh8/lhhTzucdOizgzJfbUClve4KVCivtB1/S0rX6uuZL6TZhtRDrB1bVGAkwnt6zTT/irQ1ly1AseLAGIdA+03ikQ4gD1hL+MPURko4O9qWyDpBzPtjinRkXYTPdDe3g5jj1CZMI8uw+oOwdxf/9efeEfiQZ+pZuqgtEJttxWx3NrLqiyZhiciSVoRxyXkOltMdovzNeeeRB0KkFKhjSWhjTW0QRJ19ZsDtH3lxChQd7YFfTtYL0oe3ZkRINzHwfr1vzTVaolWTF70H4LWFaTZpmFWZ+WmmXNriUHwov2TBsCYRMAJkM72PAi8WmtWR calico@cloud

write_files:
- encoding: b64
  content: $PREPARE
  owner: root:root
  path: /root/prepare.sh
- encoding: b64
  content: $NODE
  owner: root:root
  path: /root/node.sh

runcmd:
  - [ /usr/bin/chmod, +x, /root/prepare.sh]
  - [ /root/prepare.sh, "$K3S_VERSION" ]
  - [ /usr/bin/chmod, +x, /root/node.sh ]
  - [ /root/node.sh ]
  - [ /usr/bin/chown, -R, ubuntu:ubuntu, /home/ubuntu ]
  - [ /usr/bin/systemctl, enable, k3s.service ]

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
  - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCvW2dRLu0PLQeQ5q5X76RaPvh8/lhhTzucdOizgzJfbUClve4KVCivtB1/S0rX6uuZL6TZhtRDrB1bVGAkwnt6zTT/irQ1ly1AseLAGIdA+03ikQ4gD1hL+MPURko4O9qWyDpBzPtjinRkXYTPdDe3g5jj1CZMI8uw+oOwdxf/9efeEfiQZ+pZuqgtEJttxWx3NrLqiyZhiciSVoRxyXkOltMdovzNeeeRB0KkFKhjSWhjTW0QRJ19ZsDtH3lxChQd7YFfTtYL0oe3ZkRINzHwfr1vzTVaolWTF70H4LWFaTZpmFWZ+WmmXNriUHwov2TBsCYRMAJkM72PAi8WmtWR calico@cloud
runcmd:
  - [ /usr/bin/chmod, +x, /root/prepare.sh ]
  - [ /root/prepare.sh ]
  - [ /usr/sbin/usermod -aG docker ubuntu ]
  - [ /usr/bin/systemctl, enable, docker.service ]
  - [ /usr/bin/systemctl, enable, docker-registry.service ]
EOF
