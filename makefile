# =============================================================================
# Configuration Variables
# =============================================================================

# Networking
CLUSTER_CIDR  ?= 172.16.0.0/16
SERVICE_CIDR  ?= 10.43.0.0/16
CLUSTER_DNS   ?= 10.43.0.10

# K3s configuration
K3S_VERSION            ?= v1.34.3%2Bk3s1
K3S_FEATURES_DISABLED  ?= traefik,local-storage,metrics-server
DISABLE_KUBE_PROXY     ?=

# Kubeadm configuration
KUBERNETES_RELEASE_CHANNEL    ?= stable
KUBERNETES_VERSION ?= 1.34
CONTAINERD         ?= 2.2.0
RUNC               ?= 1.4.0
CNI_PLUGIN         ?= 1.9.0

# Calico Enterprise configuration
CALIENT            ?=
CALIENT_VERSION    ?= v3.20.0
DOCKER_CONFIG      ?= enterprise_files/docker.config
CALIENT_LICENSE    ?= enterprise_files/license.yaml

# =============================================================================
# Platform Detection
# =============================================================================

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    BASE_DECODE = base64 -i
else
    BASE_DECODE = base64 -w 0
endif

# =============================================================================
# File Encoding Variables
# =============================================================================

SSH_KEY:=$(shell sed 's/^/      /' certs/id_rsa | awk '{printf "%s\\\\n", $$0}')
SSH_KEY_PUB:=$(shell cat certs/id_rsa.pub)
CA_CRT:=$(shell sed 's/^/      /' certs/ca.crt | awk '{printf "%s\\\\n", $$0}')
PREPARE:=$(shell ${BASE_DECODE} prepare.sh)
CONTROL:=$(shell ${BASE_DECODE} control.sh)
NODE:=$(shell ${BASE_DECODE} node.sh)
K3S_INSTALL:=$(shell ${BASE_DECODE} k3s.sh)
KUBEADM_INSTALL:=$(shell ${BASE_DECODE} kubeadm.sh)
REGISTRY_CONFIG=$(shell ${BASE_DECODE} registry-config.yml)
REGISTRY_CRT=$(shell ${BASE_DECODE} certs/domain.crt)
REGISTRY_KEY=$(shell ${BASE_DECODE} certs/domain.key)

# Calico Enterprise file encoding (conditional)
ifdef CALIENT
ifeq ($(wildcard enterprise_files),)
$(error CALIENT is enabled but enterprise_files/ is missing. Add enterprise_files/ to the project root or disable CALIENT)
endif

ifeq ($(wildcard $(DOCKER_CONFIG)),)
$(error CALIENT is enabled but $(DOCKER_CONFIG) was not found)
endif

ifeq ($(wildcard $(CALIENT_LICENSE)),)
$(error CALIENT is enabled but $(CALIENT_LICENSE) was not found)
endif

CALIENT_INSTALL_B64:=$(shell ${BASE_DECODE} calient-full-install.sh)
DOCKER_CONFIG_B64:=$(shell ${BASE_DECODE} $(DOCKER_CONFIG))
CALIENT_LICENSE_B64:=$(shell ${BASE_DECODE} $(CALIENT_LICENSE))
endif

# =============================================================================
# Common Substitution Patterns
# =============================================================================

# Function to generate common sed substitutions
# Usage: $(call common-subs)
define common-subs
-e "s|{{SSH_KEY}}|$(SSH_KEY)|g" \
-e "s|{{SSH_KEY_PUB}}|$(SSH_KEY_PUB)|g" \
-e "s|{{CA_CRT}}|$(CA_CRT)|g" \
-e "s|{{PREPARE}}|$(PREPARE)|g" \
-e "s|{{CLUSTER_CIDR}}|$(CLUSTER_CIDR)|g" \
-e "s|{{SERVICE_CIDR}}|$(SERVICE_CIDR)|g" \
-e "s|{{CLUSTER_DNS}}|$(CLUSTER_DNS)|g" \
-e "s|{{K3S_FEATURES_DISABLED}}|$(K3S_FEATURES_DISABLED)|g" \
-e "s|{{DISABLE_KUBE_PROXY}}|$(DISABLE_KUBE_PROXY)|g" \
-e "s|{{KUBERNETES_RELEASE_CHANNEL}}|$(KUBERNETES_RELEASE_CHANNEL)|g" \
-e "s|{{KUBERNETES_VERSION}}|$(KUBERNETES_VERSION)|g" \
-e "s|{{CONTAINERD}}|$(CONTAINERD)|g" \
-e "s|{{RUNC}}|$(RUNC)|g" \
-e "s|{{CNI_PLUGIN}}|$(CNI_PLUGIN)|g"
endef

# =============================================================================
# Targets
# =============================================================================

.PHONY: help all build clean certs ssh k3s kubeadm registry

help:
	@echo "Multipass Kubernetes environment generator"
	@echo "----------------------------------------"
	@echo "Available targets:"
	@echo "  all       - Clean, generate certs, SSH keys, and build all configurations"
	@echo "  build     - Build k3s, kubeadm, and registry configurations"
	@echo "  k3s       - Generate k3s control and node initialization files"
	@echo "  kubeadm   - Generate kubeadm control and node initialization files"
	@echo "  registry  - Generate registry initialization file"
	@echo "  certs     - Generate SSL certificates for registry"
	@echo "  ssh       - Generate SSH key pair"
	@echo "  clean     - Remove generated certs and release directories"
	@echo "  help      - Show this help message"
	@echo ""
	@echo "Calico Enterprise:"
	@echo "  CALIENT=true make k3s  - Generate k3s configs with Calico Enterprise"
	@echo "  Requires docker.config and calient-license.sh in project root"
	@echo ""
	@echo ""
	@echo "Report issues in https://github.com/frozenprocess/multipass_labs"
	@echo ""


k3s: | release/k3s
	@echo "Generating k3s configuration files..."
ifdef CALIENT
	@echo "  Calico Enterprise variant enabled"
	sed $(call common-subs) \
		-e "s|{{CONTROL}}|$(CONTROL)|g" \
		-e "s|{{INSTALL}}|$(K3S_INSTALL)|g" \
		-e "s|{{K3S_VERSION}}|$(K3S_VERSION)|g" \
		-e "s|{{CALIENT_VERSION}}|$(CALIENT_VERSION)|g" \
		-e "s|{{CALIENT_INSTALL}}|$(CALIENT_INSTALL_B64)|g" \
		-e "s|{{DOCKER_CONFIG}}|$(DOCKER_CONFIG_B64)|g" \
		-e "s|{{CALIENT_LICENSE}}|$(CALIENT_LICENSE_B64)|g" \
		templates/calient-control.yaml > release/k3s/control-init.yaml
else
	sed $(call common-subs) \
		-e "s|{{CONTROL}}|$(CONTROL)|g" \
		-e "s|{{INSTALL}}|$(K3S_INSTALL)|g" \
		-e "s|{{K3S_VERSION}}|$(K3S_VERSION)|g" \
		templates/control.yaml > release/k3s/control-init.yaml
endif

	sed $(call common-subs) \
		-e "s|{{NODE}}|$(NODE)|g" \
		-e "s|{{INSTALL}}|$(K3S_INSTALL)|g" \
		-e "s|{{K3S_VERSION}}|$(K3S_VERSION)|g" \
		templates/node.yaml > release/k3s/node-init.yaml
	@echo "k3s configuration files generated in release/k3s/"

kubeadm: | release/kubeadm
	@echo "Generating kubeadm configuration files..."
	sed $(call common-subs) \
		-e "s|{{CONTROL}}|$(CONTROL)|g" \
		-e "s|{{INSTALL}}|$(KUBEADM_INSTALL)|g" \
		-e "s|{{K3S_VERSION}}|$(K3S_VERSION)|g" \
		templates/control.yaml > release/kubeadm/control-init.yaml

	sed $(call common-subs) \
		-e "s|{{NODE}}|$(NODE)|g" \
		-e "s|{{INSTALL}}|$(KUBEADM_INSTALL)|g" \
		-e "s|{{K3S_VERSION}}|$(K3S_VERSION)|g" \
		templates/node.yaml > release/kubeadm/node-init.yaml
	@echo "kubeadm configuration files generated in release/kubeadm/"

registry: | release/k3s release/kubeadm
	@echo "Generating registry configuration file..."
	sed \
		-e "s|{{PREPARE}}|$(PREPARE)|g" \
		-e "s|{{REGISTRY_CONFIG}}|$(REGISTRY_CONFIG)|g" \
		-e "s|{{REGISTRY_CRT}}|$(REGISTRY_CRT)|g" \
		-e "s|{{REGISTRY_KEY}}|$(REGISTRY_KEY)|g" \
		-e "s|{{SSH_KEY_PUB}}|$(SSH_KEY_PUB)|g" \
		templates/registry.yaml > release/kubeadm/registry-init.yaml
	cp release/kubeadm/registry-init.yaml release/k3s/registry-init.yaml
	@echo "Registry configuration file generated in release/k3s/ and release/kubeadm/"

certs: | certs-dir
	@echo "Generating SSL certificates..."
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
	@echo "SSL certificates generated in certs/"

ssh: | certs-dir
	@echo "Generating SSH key pair..."
	ssh-keygen -t rsa -b 2048 -f certs/id_rsa -q -N ""
	@echo "SSH key pair generated in certs/"

build: k3s kubeadm registry
	@echo "Build complete!"

all: clean certs ssh build
	@echo "All targets completed successfully!"

clean:
	@echo "Cleaning generated files..."
	rm -rf certs release
	@echo "Clean complete!"

# =============================================================================
# Directory Prerequisites
# =============================================================================

release/k3s:
	mkdir -p release/k3s

release/kubeadm:
	mkdir -p release/kubeadm

certs-dir:
	mkdir -p certs
