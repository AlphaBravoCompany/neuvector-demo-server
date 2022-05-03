# Neuvector Demo Server

## About Neuvector 

NeuVector Full Lifecycle Container Security Platform delivers the only cloud-native security with uncompromising end-to-end protection from DevOps vulnerability protection to automated run-time security, and featuring a true Layer 7 container firewall.

A viewable version of docs can be seen at https://open-docs.neuvector.com

Chart: https://neuvector.github.io/neuvector-helm/
Repo: https://github.com/neuvector/neuvector-helm
Website: https://neuvector.com/

## Intended usage of this script

This script is for demo purposes only. It deploys a bare minimum, single node K3s Kubernetes cluster, Longhorn Storage, and the Beta of Neuvector and provides links to the interfaces and login information.

## Prerequisites
- Ubuntu 20.04+ Server
- Minimum of 2vCPU and 4GB of RAM
- DNS or Hosts file entry pointing to server IP

## Installed as part of script

- Helm
- K3s
- Rancher UI
- Longhorn Storage
- cert-manager
- Neuvector 5 Beta

## Full Server Setup with Neuvector Helm Chart

1. `git clone https://github.com/AlphaBravoCompany/neuvector-demo-server.git`
2. `cd neuvector-demo`
3. `./install-neuvector.sh subdomain.yourdomain.tld`

# Uninstall

1. `/usr/local/bin/k3s-uninstall.sh` (removes K3s, Rancher, Longhorn and Neuvector)

## About Alphabravo

**AlphaBravo** provides products, services, and training for Kubernetes, Cloud, and DevSecOps. We are a Rancher and SUSE partner.

Contact **AB** today to learn how we can help you.

* **Web:** https://alphabravo.io
* **Email:** info@alphabravo.io
* **Phone:** 301-337-8141
