#!/bin/bash

set -a
source /etc/environment
set +a

TRIES=0
while [[ $(curl --write-out '%{http_code}' --silent --output /dev/null 127.0.0.1:6443) != "400" ]]
do
    if [[ $TRIES -eq 60 ]]; then
        echo "Failed to find the k3s server"
        exit 1 
    fi
    echo "Waiting for 127.0.0.1"
    sleep 1
    TRIES=$(( TRIES + 1 ))
done


echo "Creating Tigera operator"
while [[ $(kubectl get deployment tigera-operator -n tigera-operator -o=jsonpath='{.metadata.name}' 2>/dev/null) == "" ]]
do
    kubectl create -f https://downloads.tigera.io/ee/$CALIENT_VERSION/manifests/tigera-operator.yaml 2>/dev/null || true
    sleep 2
done
echo "Tigera operator created successfully"

echo "Creating Tigera Prometheus operator"
while [[ $(kubectl get deployment calico-prometheus-operator -n tigera-prometheus -o=jsonpath='{.metadata.name}' 2>/dev/null) == "" ]]
do
    kubectl create -f https://downloads.tigera.io/ee/$CALIENT_VERSION/manifests/tigera-prometheus-operator.yaml 2>/dev/null || true
    sleep 2
done
echo "Tigera Prometheus operator created successfully"

echo "Creating pull secret in tigera-operator namespace"
while [[ $(kubectl get secret tigera-pull-secret -n tigera-operator -o=jsonpath='{.metadata.name}' 2>/dev/null) == "" ]]
do
    kubectl create secret generic tigera-pull-secret \
        --type=kubernetes.io/dockerconfigjson -n tigera-operator \
        --from-file=.dockerconfigjson=/root/docker.config 2>/dev/null || true
    sleep 2
done
echo "Pull secret created in tigera-operator namespace"

echo "Creating pull secret in tigera-prometheus namespace"
while [[ $(kubectl get secret tigera-pull-secret -n tigera-prometheus -o=jsonpath='{.metadata.name}' 2>/dev/null) == "" ]]
do
    kubectl create secret generic tigera-pull-secret \
        --type=kubernetes.io/dockerconfigjson -n tigera-prometheus \
        --from-file=.dockerconfigjson=/root/docker.config 2>/dev/null || true
    sleep 2
done
echo "Pull secret created in tigera-prometheus namespace"

kubectl patch deployment -n tigera-prometheus calico-prometheus-operator \
    -p '{"spec":{"template":{"spec":{"imagePullSecrets":[{"name": "tigera-pull-secret"}]}}}}'


echo "Creating storage resources"
while [[ $(kubectl get storageclass tigera-elasticsearch -o=jsonpath='{.metadata.name}' 2>/dev/null) == "" ]]
do
    kubectl create  -f - <<EOF 2>/dev/null || true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: tigera-elasticsearch
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: tigera-elasticsearch-1
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /var/tigera/elastic-data/1
  persistentVolumeReclaimPolicy: Retain
  storageClassName: tigera-elasticsearch
EOF
    sleep 2
done
echo "Storage resources created successfully"


all_calico_enterprise_resources_exist() {
  [[ -n "$(kubectl get installation default -o=jsonpath='{.metadata.name}' 2>/dev/null)" ]] &&
  [[ -n "$(kubectl get logstorage tigera-secure -o=jsonpath='{.metadata.name}' 2>/dev/null)" ]] &&
  [[ -n "$(kubectl get apiserver tigera-secure -o=jsonpath='{.metadata.name}' 2>/dev/null)" ]] &&
  [[ -n "$(kubectl get manager tigera-secure -o=jsonpath='{.metadata.name}' 2>/dev/null)" ]] &&
  [[ -n "$(kubectl get monitor tigera-secure -o=jsonpath='{.metadata.name}' 2>/dev/null)" ]] &&
  [[ -n "$(kubectl get logcollector tigera-secure -o=jsonpath='{.metadata.name}' 2>/dev/null)" ]] &&
  [[ -n "$(kubectl get compliance tigera-secure -o=jsonpath='{.metadata.name}' 2>/dev/null)" ]]
}

version_gte() {
  local current="${1#v}"
  local minimum="${2#v}"
  [[ "$(printf '%s\n' "$minimum" "$current" | sort -V | head -n1)" == "$minimum" ]]
}

echo "Creating Calico Enterprise resources"
while ! all_calico_enterprise_resources_exist
do
  kubectl create -f -<<EOF 2>/dev/null || true
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  variant: TigeraSecureEnterprise
  flexVolumePath: None
  calicoNetwork:
    bgp: Enabled
    ipPools:
    - cidr: $CLUSTER_CIDR
      encapsulation: VXLAN
  imagePullSecrets:
    - name: tigera-pull-secret
---
apiVersion: operator.tigera.io/v1
kind: LogStorage
metadata:
  name: tigera-secure
spec:
  componentResources:
  - componentName: ECKOperator
    resourceRequirements:
      limits:
        memory: 512Mi
      requests:
        memory: 512Mi
  indices:
    replicas: 0
  nodes:
    count: 1
    resourceRequirements:
      limits:
        cpu: "2"
        memory: 6Gi
      requests:
        storage: 5Gi
  retention:
    auditReports: 91
    complianceReports: 91
    flows: 8
    snapshots: 91
  storageClassName: tigera-elasticsearch
---
apiVersion: operator.tigera.io/v1
kind: APIServer
metadata:
  name: tigera-secure
---
apiVersion: operator.tigera.io/v1
kind: Manager
metadata:
  name: tigera-secure
---
apiVersion: operator.tigera.io/v1
kind: Monitor
metadata:
  name: tigera-secure
---
apiVersion: operator.tigera.io/v1
kind: LogCollector
metadata:
  name: tigera-secure
---
apiVersion: operator.tigera.io/v1
kind: Compliance
metadata:
  name: tigera-secure
EOF
    sleep 2
done
echo "Calico Enterprise resources created successfully"

# Wait for APIServer
echo "Waiting for APIServer"
while [[ $(kubectl get tigerastatus -o=jsonpath='{.items[?(@.metadata.name=="apiserver")].status.conditions[?(@.type=="Available")].status}') != "True" ]]
do
    sleep 1
done

sleep 2

echo "Applying license"
while [[ $(kubectl get licensekey default -o=jsonpath='{.status.expiry}' 2>/dev/null) == "" || $(kubectl get licensekey default -o=jsonpath='{.status.expiry}' 2>/dev/null) == "null" ]]
do
    kubectl apply -f /root/license.yaml
    sleep 5
done
echo "License applied successfully"

echo "Waiting for Tigera Manager"
while [[ $(kubectl get tigerastatus -o=jsonpath='{.items[?(@.metadata.name=="manager")].status.conditions[?(@.type=="Available")].status}') != "True" ]]
do
    kubectl get tigerastatus
    sleep 1
done

# Let's show off the UI
if version_gte "$CALIENT_VERSION" "v3.23"; then
    echo "Creating Tigera Manager external service"
    while [[ $(kubectl get service tigera-manager-external -n tigera-manager -o=jsonpath='{.metadata.name}' 2>/dev/null) == "" ]]
    do
        kubectl create -f -<<EOF 2>/dev/null || true
apiVersion: v1
kind: Service
metadata:
  name: tigera-manager-external
  namespace: tigera-manager
spec:
  type: LoadBalancer
  selector:
    k8s-app: tigera-manager
  externalTrafficPolicy: Local
  ports:
    - port: 9443
      targetPort: 9443
      protocol: TCP
EOF
        sleep 2
    done
    echo "Tigera Manager external service created successfully"
else
    echo "Creating Tigera Manager public service"
    while [[ $(kubectl get service tigera-manager-public -n tigera-manager -o=jsonpath='{.metadata.name}' 2>/dev/null) == "" ]]
    do
        kubectl create -f -<<EOF 2>/dev/null || true
apiVersion: v1
kind: Service
metadata:
  name: tigera-manager-public
  namespace: tigera-manager
spec:
  ports:
  - nodePort: 31280
    port: 9443
    protocol: TCP
    targetPort: 9443
  selector:
    k8s-app: tigera-manager
  type: LoadBalancer
EOF
        sleep 2
    done
    echo "Tigera Manager public service created successfully"
fi

echo "Creating service account for demo"
while [[ $(kubectl get sa calidemo -n default -o=jsonpath='{.metadata.name}' 2>/dev/null) == "" ]]
do
    kubectl create sa calidemo -n default 2>/dev/null || true
    sleep 2
done
echo "Service account created successfully"

echo "Creating cluster role binding"
while [[ $(kubectl get clusterrolebinding calidemo-access -o=jsonpath='{.metadata.name}' 2>/dev/null) == "" ]]
do
    kubectl create clusterrolebinding calidemo-access --clusterrole tigera-network-admin --serviceaccount default:calidemo 2>/dev/null || true
    sleep 2
done
echo "Cluster role binding created successfully"

echo "Creating service account token secret"
while [[ $(kubectl get secret calidemo -n default -o=jsonpath='{.metadata.name}' 2>/dev/null) == "" ]]
do
    kubectl create -f - <<EOF 2>/dev/null || true
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: calidemo
  annotations:
    kubernetes.io/service-account.name: "calidemo"
EOF
    sleep 2
done
echo "Service account token secret created successfully"
