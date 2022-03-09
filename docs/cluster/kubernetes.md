# Kubernetes Cluster

The EOEPCA Reference Implementation has been developed with Kubernetes as its deployment target. The system components have been developed, deployed and tested using a cluster at version `v1.18.10`.

## Rancher Kubernetes Engine (RKE)

The development, integration and test clusters have been established using [Rancher Kubernetes Engine (RKE)](https://rancher.com/products/rke) at version `v1.18.10`.

An example of the creation of the EOEPCA Kubernetes clusters can be found on the [GitHub Kubernetes Setup page](https://github.com/EOEPCA/eoepca/tree/develop/kubernetes#readme). [CREODIAS](https://creodias.eu/) has been used for the development hosting infrastructure - which provides OpenStack infrastructure that is backed by [Cloudferro](https://cloudferro.com/). An example of the [Terraform](https://www.terraform.io/) configurations used to automate the creation of the cloud infrastructure that underpins the RKE deployment can be found on the [GitHub CREODIAS Setup page](https://github.com/EOEPCA/eoepca/tree/develop/creodias#readme).

## Local Kubernetes

To make a full deployment of the EOEPCA Reference Implementation requires a multi-node node cluster with suitable resources. For example, the development cluster comprises:

* 1 Master node (2 vCPU, 8 GB RAM)
* 5 Worker nodes (4 vCPU, 16 GB RAM)
* 1 NFS server (2 vCPU, 8 GB RAM)

Limited local deployment can be made using a suitable local single-node kuberbetes deployment using - for example using [minikube](https://minikube.sigs.k8s.io/)...

```
minikube -p eoepca start --cpus max --memory max --kubernetes-version v1.21.5
minikube profile eoepca
```

With such a deployment it is possible to deploy individual building-blocks for local development, or building-blocks in combination - within the constraints of the local host resources.
