# Multipass labs

This is a simple project to quickly spin up Kubernetes clusters in multipass.

# How does this work?
Run the make file to generate cloud-init files
```
make all
```

# How to spin up a cluster?

## Kubeadm

```
multipass launch -n c1-control -c 2 -d 50G -m 2048M 24.04 --cloud-init  release/kubeadm/control-init.yaml
multipass launch -n c1-node-1 -c 2 -d 50G  -m 2048M 24.04 --cloud-init  release/kubeadm/node-init.yaml
```

```
multipass transfer c1-control:/home/ubuntu/.kube/config .
```

## K3s

```
multipass launch -n c1-control -c 2 -d 50G -m 2048M 24.04 --cloud-init  release/k3s/control-init.yaml
multipass launch -n c1-node-1 -c 2 -d 50G  -m 2048M 24.04 --cloud-init  release/k3s/node-init.yaml
```

```
multipass transfer c1-control:/etc/rancher/k3s/k3s.yaml .
```

You can create multiple nodes by changing the node name in the last command and running it again
```
multipass launch -n c1-node-2 -c 2 -d 50G  -m 2048M 24.04 --cloud-init  release/node-init.yaml
multipass launch -n c1-node-3 -c 2 -d 50G  -m 2048M 24.04 --cloud-init  release/node-init.yaml
```


sudo launchctl unload /Library/LaunchDaemons/com.canonical.multipassd.plist


# Is it possible to use a trusted cert?
Yes, try [Docker](https://docs.docker.com/registry/deploying/#support-for-lets-encrypt) documentation.
