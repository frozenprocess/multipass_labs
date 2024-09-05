#!/bin/bash
#K3S_VERSION="v1.23.16%2Bk3s1"
#K3S_VERSION="v1.25.8%2Bk3s1"
K3S_VERSION=$1

ARCH=`uname -m`
if [[ $ARCH == "x86_64" ]]
then
echo "Downloading k3s binary for $ARCH"
/usr/bin/curl -L https://github.com/k3s-io/k3s/releases/download/$K3S_VERSION/k3s -o /usr/local/bin/k3s
echo "Downloading calicoctl binary $ARCH"
/usr/bin/curl -L https://github.com/projectcalico/calico/releases/latest/download/calicoctl-linux-amd64 -o /usr/local/bin/calicoctl
else
echo "Downloading k3s binary for $ARCH"
/usr/bin/curl -L https://github.com/k3s-io/k3s/releases/download/$K3S_VERSION/k3s-arm64 -o /usr/local/bin/k3s
echo "Downloading calicoctl binary $ARCH"
/usr/bin/curl -L https://github.com/projectcalico/calico/releases/latest/download/calicoctl-linux-arm64 -o /usr/local/bin/calicoctl
fi

/usr/bin/chmod +x /usr/local/bin/k3s
/usr/bin/chmod +x /usr/local/bin/calicoctl 

/usr/bin/curl https://get.k3s.io/ > /root/install.sh
/usr/bin/chmod +x /root/install.sh

# Mac OS discovery fix
cat >> /etc/systemd/resolved.conf <<-EOF
MulticastDNS=yes
Domains=multipass mshome.net local
EOF

cat >> /etc/sysctl.conf <<-EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

sysctl -p

INTERFACE=`ip link show  | egrep "[0-9]: en" | awk '{ print $2 }' | cut -d: -f1`

/usr/bin/systemctl enable systemd-resolved.service
/usr/bin/systemctl restart systemd-resolved.service

cat > /etc/systemd/system/mdns@.service <<-EOF
[Service]
Type=oneshot
ExecStart=/usr/bin/resolvectl mdns %i yes
After=sys-subsystem-net-devices-%i.device

[Install]
WantedBy=sys-subsystem-net-devices-%i.device
EOF

/usr/bin/systemctl enable mdns@$INTERFACE.service
/usr/bin/systemctl start mdns@$INTERFACE.service
/usr/bin/systemctl restart systemd-resolved.service
# Mac OS discovery fix
