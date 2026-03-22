# Multipass labs

Generate cloud-init files for fast Kubernetes lab environments on Multipass.

## What gets generated

The Makefile renders templates into `release/`:

- `release/k3s/control-init.yaml`
- `release/k3s/node-init.yaml`
- `release/k3s/registry-init.yaml`
- `release/kubeadm/control-init.yaml`
- `release/kubeadm/node-init.yaml`
- `release/kubeadm/registry-init.yaml`

## Quick start

Generate everything (clean, certs, ssh keys, k3s, kubeadm, registry):

```bash
make all
```

Generate only cloud-init artifacts (without cleaning/recreating certs and keys):

```bash
make build
```

Show all available targets:

```bash
make help
```

## Make targets

- `make k3s`: Generate k3s control/node cloud-init files.
- `make kubeadm`: Generate kubeadm control/node cloud-init files.
- `make registry`: Generate registry cloud-init for both k3s and kubeadm.
- `make certs`: Generate TLS certs under `certs/`.
- `make ssh`: Generate SSH key pair under `certs/`.
- `make clean`: Remove generated `certs/` and `release/`.
- `make build`: Run `k3s`, `kubeadm`, `registry`.
- `make all`: Run `clean`, `certs`, `ssh`, `build`.

## Configurable variables

Pass variables inline to customize generated files:

```bash
VAR=value make <target>
```

Common networking and k3s variables:

- `CLUSTER_CIDR` (default: `172.16.0.0/16`)
- `SERVICE_CIDR` (default: `10.43.0.0/16`)
- `CLUSTER_DNS` (default: `10.43.0.10`)
- `K3S_VERSION` (default: `v1.34.3%2Bk3s1`)
- `K3S_FEATURES_DISABLED` (default: `traefik,local-storage,metrics-server`)
- `DISABLE_KUBE_PROXY` (empty by default)

Kubeadm-related variables:

- `KUBERNETES_RELEASE_CHANNEL` (default: `stable`)
- `KUBERNETES_VERSION` (default: `1.34`)
- `CONTAINERD` (default: `2.2.0`)
- `RUNC` (default: `1.4.0`)
- `CNI_PLUGIN` (default: `1.9.0`)

Calico Enterprise variables:

- `CALIENT=true` enables Calico Enterprise flow for `make k3s`
- `CALIENT_VERSION` (default: `v3.20.0`)
- `DOCKER_CONFIG` (default: `enterprise_files/docker.config`)
- `CALIENT_LICENSE` (default: `enterprise_files/license.yaml`)

## Launching a kubeadm cluster

Generate kubeadm artifacts:

```bash
make kubeadm
```

Or with explicit runtime versions:

```bash
KUBERNETES_VERSION=1.34 CONTAINERD=2.2.0 RUNC=1.4.0 CNI_PLUGIN=1.9.0 make kubeadm
```

Launch nodes:

```bash
multipass launch -n c1-control -c 2 -d 50G -m 2048M 22.04 --cloud-init release/kubeadm/control-init.yaml
multipass launch -n c1-node-1 -c 2 -d 50G -m 2048M 22.04 --cloud-init release/kubeadm/node-init.yaml
```
> **Note**: Make sure you update the ipaddress in the config file.

Export kubeconfig:

```bash
multipass transfer c1-control:/home/ubuntu/.kube/config .
```

## Launching a k3s cluster

Generate k3s artifacts:

```bash
make k3s
```

Launch nodes:

```bash
multipass launch -n c1-control -c 4 -d 50G -m 8G 24.04 --cloud-init release/k3s/control-init.yaml
multipass launch -n c1-node-1 -c 4 -d 50G -m 8G 24.04 --cloud-init release/k3s/node-init.yaml
```

> **Note**: Make sure you update the ipaddress in the config file.

Export kubeconfig:

```bash
multipass transfer c1-control:/etc/rancher/k3s/k3s.yaml .
```

Add more workers:

```bash
multipass launch -n c1-node-2 -c 2 -d 50G -m 2048M 24.04 --cloud-init release/k3s/node-init.yaml
multipass launch -n c1-node-3 -c 2 -d 50G -m 2048M 24.04 --cloud-init release/k3s/node-init.yaml
```

## Private registry support

Generate registry cloud-init for both distributions:

```bash
make registry
```

If you want trusted/public certs instead of self-signed certs, see Docker Registry TLS guidance:
https://docs.docker.com/registry/deploying/#support-for-lets-encrypt

## Calico Enterprise on k3s

Generate k3s control/node files with Calico Enterprise installer payloads:

```bash
CALIENT=true CALIENT_VERSION="v3.23.0-1.0" make certs ssh k3s
```

You can override related file paths if needed:

```bash
CALIENT=true DOCKER_CONFIG=enterprise_files/docker.config CALIENT_LICENSE=enterprise_files/license.yaml make k3s
```

> **Note**: Enterprise offers more features make sure to upgrade the vms.
```bash
multipass launch -n c1-control -c 4 -d 50G -m 8G 24.04 --cloud-init release/k3s/control-init.yaml
multipass launch -n c1-node-1 -c 4 -d 50G -m 8G 24.04 --cloud-init release/k3s/node-init.yaml
```

## macOS note

If Multipass hangs, reloading the daemon can help:

```zsh
sudo launchctl unload /Library/LaunchDaemons/com.canonical.multipassd.plist
```
