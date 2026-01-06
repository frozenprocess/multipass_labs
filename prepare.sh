#!/bin/bash

set -a
source /etc/environment
set +a

# WHATS the ARCH?
if [[ `uname -m` == "x86_64" ]]
then
ARCH="amd64"
else
ARCH="arm64"
fi

echo "Downloading calicoctl binary $ARCH"

/usr/bin/curl -L https://github.com/projectcalico/calico/releases/latest/download/calicoctl-linux-$ARCH -o /usr/local/bin/calicoctl
/usr/bin/chmod +x /usr/local/bin/calicoctl 

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
