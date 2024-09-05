
# How did you build these certificates for private-repo?

Use the following command to generate a CA key:
```
openssl genrsa -out certs/ca.key 2048
```

Use the following command to generate a CA certificate:
```
openssl req -new -x509 -key certs/ca.key \
    -subj '/CN=private-repo/O=We love Calico/C=US' \
    -days 1024 -out certs/ca.crt
```

Use the following command to generate a certificate request for the private-repo instance:
```
openssl req \
  -newkey rsa:2048 -nodes -sha256 -keyout certs/domain.key \
  -subj '/CN=private-repo/O=We love Calico/C=US' \
  -addext "subjectAltName=DNS:private-repo,DNS:private-repo.multipass,DNS:private-repo.mshome.net,DNS:private-repo,DNS:private-repo.local" \
  -out certs/domain.csr 
```

Finally, sign your certificate with the CA key. 
```
openssl x509 -req \
    -in certs/domain.csr \
    -CA certs/ca.crt -CAkey certs/ca.key \
    -out certs/domain.crt \
    -days 1024 \
    -sha256 -extensions v3_req -extfile req.conf
```

```
multipass launch -n c1-control -c 2 -d 50G -m 2048M 24.04 --cloud-init  release/control-init.yaml
multipass launch -n c1-node -c 2 -d 50G  -m 2048M 24.04 --cloud-init  release/node-init.yaml

multipass launch -n c2-control -c 2 -m 2048M 22.04 --cloud-init  release/control-init.yaml
multipass launch -n c2-node -c 2 -m 2048M 22.04 --cloud-init  release/node-init.yaml

multipass launch -n c3-control -c 2 -m 2048M 22.04 --cloud-init  release/control-init.yaml
multipass launch -n c3-node -c 2 -m 2048M 22.04 --cloud-init  release/node-init.yaml
```

# Is it possible to use a trusted cert?
Yes, try [Docker](https://docs.docker.com/registry/deploying/#support-for-lets-encrypt) documentation.
