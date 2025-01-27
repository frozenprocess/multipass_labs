
CLUSTER_CIDR="172.16.0.0/16"
SERVICE_CIDR="10.43.0.0/16"
CLUSTER_DNS="10.43.0.10"
## K3S VARS
K3S_VERSION="v1.32.0%2Bk3s1"
#K3S_FEATURES_DISABLED="traefik,local-storage,metrics-server,servicelb"
K3S_FEATURES_DISABLED="traefik,local-storage,metrics-server"
#DISABLE_KUBE_PROXY="--disable-kube-proxy"
DISABLE_KUBE_PROXY=""
## KUBEADM VARS
KUBERNETES_VERSION=1.31
CIDR=172.16.0.0
CONTAINERD=2.0.2
RUNC=1.2.4
CNI_PLUGIN=1.6.2

# What form of nonsense OS are you running?
@if [[ $$(uname -s) == "Darwin" ]]; then \
	BASE_DECODE="base64 -i"; \
else \
	BASE_DECODE="base64 -w 0"; \
fi; \

SSH_KEY:=$(shell cat ${HOME}/.ssh/id_rsa.pub)
# YAML is annoying so we pad the cert
CA_CRT:=$(shell sed 's/^/      /' certs/ca.crt | awk '{printf "%s\\\\n", $$0}')
PREPARE:=$(shell ${BASE_DECODE} prepare.sh)
CONTROL:=$(shell base64 -i control.sh)
K3S_INSTALL:=$(shell base64 -i k3s.sh)
KUBEADM_INSTALL:=$(shell base64 -i kubeadm.sh)
# Private registry
REGISTRY_CONFIG=$(shell base64 -i registry-config.yml)
REGISTRY_CRT=$(shell base64 -i certs/domain.crt)
REGISTRY_KEY=$(shell base64 -i certs/domain.key)

help:
	echo "helping"

k3s:

	mkdir -p release/k3s

	sed \
		-e "s|{{SSH_KEY}}|${SSH_KEY}|g" \
		-e "s|{{CA_CRT}}|${CA_CRT}|g" \
		-e "s|{{PREPARE}}|${PREPARE}|g" \
		-e "s|{{CONTROL}}|${CONTROL}|g" \
		-e "s|{{INSTALL}}|${K3S_INSTALL}|g" \
		templates/control.yaml > release/k3s/control-init.yaml

	sed \
		-e "s|{{SSH_KEY}}|${SSH_KEY}|g" \
		-e "s|{{CA_CRT}}|${CA_CRT}|g" \
		-e "s|{{PREPARE}}|${PREPARE}|g" \
		-e "s|{{NODE}}|${NODE}|g" \
		-e "s|{{INSTALL}}|${K3S_INSTALL}|g" \
		templates/node.yaml > release/k3s/node-init.yaml

kubeadm:

	mkdir -p release/kubeadm

	sed \
		-e "s|{{SSH_KEY}}|${SSH_KEY}|g" \
		-e "s|{{CA_CRT}}|${CA_CRT}|g" \
		-e "s|{{PREPARE}}|${PREPARE}|g" \
		-e "s|{{CONTROL}}|${CONTROL}|g" \
		-e "s|{{INSTALL}}|${KUBEADM_INSTALL}|g" \
		templates/control.yaml > release/kubeadm/control-init.yaml

	sed \
		-e "s|{{SSH_KEY}}|${SSH_KEY}|g" \
		-e "s|{{CA_CRT}}|${CA_CRT}|g" \
		-e "s|{{PREPARE}}|${PREPARE}|g" \
		-e "s|{{NODE}}|${NODE}|g" \
		-e "s|{{INSTALL}}|${KUBEADM_INSTALL}|g" \
		templates/node.yaml > release/kubeadm/node-init.yaml

registry:

	mkdir -p release/k3s
	mkdir -p release/kubeadm

	sed \
		-e "s|{{PREPARE}}|${PREPARE}|g" \
		-e "s|{{REGISTRY_CONFIG}}|${REGISTRY_CONFIG}|g" \
		-e "s|{{REGISTRY_CRT}}|${REGISTRY_CRT}|g" \
		-e "s|{{REGISTRY_KEY}}|${REGISTRY_KEY}|g" \
		-e "s|{{SSH_KEY}}|${SSH_KEY}|g" \
		templates/registry.yaml > release/kubeadm/registry-init.yaml
		cp release/kubeadm/registry-init.yaml release/k3s/registry-init.yaml

certs:
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

build: k3s kubeadm registry



# $$BASE_DECODE templates/control.yaml
# $$BASE_DECODE templates/control.yaml

all: clean certs build

clean:
	rm -rf certs
	rm -rf release

.PHONY: clean help