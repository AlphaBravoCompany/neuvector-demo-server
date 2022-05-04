#!/bin/bash

set -e
G="\e[32m"
E="\e[0m"

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
echo "Updating OS packages..."
sudo apt update > /dev/null 2>&1
sudo apt upgrade -y > /dev/null 2>&1

## Install Prereqs
echo "Installing Prereqs..."
sudo apt-get update > /dev/null 2>&1
sudo apt-get install -y \
apt-transport-https ca-certificates curl gnupg lsb-release \
software-properties-common haveged bash-completion  > /dev/null 2>&1

## Install Helm
echo "Installing Helm..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3  > /dev/null 2>&1
chmod 700 get_helm.sh  > /dev/null 2>&1
./get_helm.sh  > /dev/null 2>&1
rm ./get_helm.sh  > /dev/null 2>&1


## Install K3s
echo "Installing K3s..."
sudo curl -sfL https://get.k3s.io | sh -  > /dev/null 2>&1
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml  > /dev/null 2>&1

## Wait for K3s to come online
echo "Waiting for K3s to come online...."
until [ $(kubectl get nodes|grep Ready | wc -l) = 1 ]; do echo -n "." ; sleep 2; done  > /dev/null 2>&1

## Install Longhorn
echo "Deploying Longhorn on K3s..."
helm repo add longhorn https://charts.longhorn.io > /dev/null 2>&1
helm repo update > /dev/null 2>&1
helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace > /dev/null 2>&1

## Wait for Longhorn
echo "Waiting for Longhorn deployment to finish..."
until [ $(kubectl -n longhorn-system rollout status deploy/longhorn-ui|grep successfully | wc -l) = 1 ]; do echo -n "." ; sleep 2; done > /dev/null 2>&1

## Install Neuvector
echo "Deploying Neuvector on K3s..."
helm repo add neuvector https://neuvector.github.io/neuvector-helm/ > /dev/null 2>&1
helm repo update > /dev/null 2>&1
kubectl create namespace neuvector > /dev/null 2>&1
helm install neuvector --namespace neuvector neuvector/core -f https://gist.githubusercontent.com/mjtechguy/cc247abf0e7ef0ede2d9ec1abb8ccd9b/raw/dc112455667efd577f952ff129892f710899d2a8/values.yaml > /dev/null 2>&1

## Wait for Neuvector
echo "Waiting for Neuvector to come online..."
until [ $(kubectl -n neuvector rollout status deploy/neuvector-manager-pod|grep successfully | wc -l) = 1 ]; do echo -n "." ; sleep 2; done > /dev/null 2>&1
until [ $(kubectl -n neuvector rollout status deploy/neuvector-scanner-pod|grep successfully | wc -l) = 1 ]; do echo -n "." ; sleep 2; done > /dev/null 2>&1
until [ $(kubectl -n neuvector rollout status deploy/neuvector-controller-pod|grep successfully | wc -l) = 1 ]; do echo -n "." ; sleep 2; done > /dev/null 2>&1

## Print Neuvector WebUI Link (Nodeport)
NODE_PORT=$(kubectl get --namespace neuvector -o jsonpath="{.spec.ports[0].nodePort}" services neuvector-service-webui) > /dev/null 2>&1
NODE_IP=$(kubectl get nodes --namespace neuvector -o jsonpath="{.items[0].status.addresses[0].address}") > /dev/null 2>&1
export NEUVECTORUI=https://$NODE_IP:$NODE_PORT > /dev/null 2>&1

## Install Cert-Manager
# Install the CustomResourceDefinition resources separately
echo "Deploying cert-manager on K3s..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.8.0/cert-manager.crds.yaml > /dev/null 2>&1

# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io > /dev/null 2>&1

# Update your local Helm chart repository cache
helm repo update > /dev/null 2>&1

# Install the cert-manager Helm chart
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.8.0  > /dev/null 2>&1

## Wait for cert-manager
echo "Waiting for cert-manager deployment to finish..."
until [ $(kubectl -n cert-manager rollout status deploy/cert-manager|grep successfully | wc -l) = 1 ]; do echo -n "." ; sleep 2; done > /dev/null 2>&1

## Install Rancher
echo "Deploying Rancher on K3s..."
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable > /dev/null 2>&1
kubectl create namespace cattle-system > /dev/null 2>&1
helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=$1 > /dev/null 2>&1

## Wait for Rancher
echo "Waiting for Rancher UI to come online...."
until [ $(kubectl -n cattle-system rollout status deploy/rancher|grep successfully | wc -l) = 1 ]; do echo -n "." ; sleep 2; done > /dev/null 2>&1

## Get Rancher Password
echo "Exporting Rancher UI password..."
export RANCHERPW=$(kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{ .data.bootstrapPassword|base64decode}}{{ "\n" }}') > /dev/null 2>&1

## Print Server Information and Links
touch ./server-details.txt
echo -----------------------------------------------
echo -e ${G}Install is complete. Please use the below information to access your environment.${E} | tee ./server-details.txt
echo -e ${G}Please update your DNS or Hosts file to point https://$1 to the IP of this server $NODE_IP.${E} | tee -a ./server-details.txt
echo -e ${G}Neuvector UI:${E} $NEUVECTORUI | tee -a ./server-details.txt
echo -e ${G}Neuvector Login:${E} admin/admin \(please change the default password immediately\) | tee -a ./server-details.txt
echo -e ${G}Rancher UI:${E} https://$1 | tee -a ./server-details.txt
echo -e ${G}Rancher Password:${E} $RANCHERPW | tee -a ./server-details.txt
echo -e ${G}Kubeconfig File:${E} /etc/rancher/k3s/k3s.yaml | tee -a ./server-details.txt
echo Details above are saved to the file at ./server-details.txt
echo -----------------------------------------------
