#!/bin/bash

set -e

if [ -z "$1" ]
  then
    echo -----------------------------------------------
    echo -e "Please provide your desired Rancher DNS name as part of the install command. eg: ./install.sh rancher.mydomain.tld."
    echo -----------------------------------------------
    exit 1
fi

if ! grep -q 'Ubuntu' /etc/issue
  then
    echo -----------------------------------------------
    echo "Not Ubuntu? Could not find Codename Ubuntu in lsb_release -a. Please switch to Ubuntu."
    echo -----------------------------------------------
    exit 1
fi

## Update OS
sudo apt update && sudo apt upgrade -y

## Install Prereqs
sudo apt-get update && sudo apt-get install -y \
apt-transport-https ca-certificates curl gnupg lsb-release \
software-properties-common haveged bash-completion

## Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | sudo bash

## Install K3s
sudo curl -sfL https://get.k3s.io | sh -
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

## Wait for K3s to come online
echo "Waiting for 60 seconds while K3s comes online...."
sleep 60

## Install Longhorn
helm repo add longhorn https://charts.longhorn.io
helm repo update
helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace

## Wait for Longhorn
echo "Waiting for 30 seconds while Longhorn comes online...."
sleep 30

## Install Neuvector
helm repo add neuvector https://neuvector.github.io/neuvector-helm/
helm repo update
kubectl create namespace neuvector
helm install neuvector --namespace neuvector neuvector/core -f https://gist.githubusercontent.com/mjtechguy/cc247abf0e7ef0ede2d9ec1abb8ccd9b/raw/dc112455667efd577f952ff129892f710899d2a8/values.yaml

## Wait for Neuvector
echo "Waiting for 60 seconds while Neuvector comes online...."
sleep 30

## Print Neuvector WebUI Link (Nodeport)
NODE_PORT=$(kubectl get --namespace neuvector -o jsonpath="{.spec.ports[0].nodePort}" services neuvector-service-webui)
NODE_IP=$(kubectl get nodes --namespace neuvector -o jsonpath="{.items[0].status.addresses[0].address}")
export NEUVECTORUI=https://$NODE_IP:$NODE_PORT
echo https://$NODE_IP:$NODE_PORT 

## Install Cert-Manager
# Install the CustomResourceDefinition resources separately
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.8.0/cert-manager.crds.yaml

# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io

# Update your local Helm chart repository cache
helm repo update

# Install the cert-manager Helm chart
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.8.0 \

## Wait for cert-manager
echo "Waiting for 60 seconds while cert-manager comes online...."
sleep 60

## Install Rancher
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
kubectl create namespace cattle-system
helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=$1

## Wait for Rancher to come online
echo "Waiting for 60 seconds while Rancher comes online...."
sleep 60

## Get Rancher Password
echo "Exporting Rancher UI password..."
export RANCHERPW=$(kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{ .data.bootstrapPassword|base64decode}}{{ "\n" }}')
sleep 10

## Print Information
echo -----------------------------------------------

echo Install is complete. Please use the below information to access your environment.

echo Please update your DNS or Hosts file to point https://$1 to the IP of this server ($NODE_IP).

echo Neuvector UI: $NEUVECTORUI

echo Neuvector Login: admin/admin

echo Rancher UI: https://$1

echo Rancher Password: $RANCHERPW

echo Kubeconfig File: /etc/rancher/k3s/k3s.yaml

echo -----------------------------------------------