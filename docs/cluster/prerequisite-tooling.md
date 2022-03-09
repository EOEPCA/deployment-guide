# Prerequisite Tooling

There are some standard tools referenced in this guide. These are detailed in the following subsections.

## docker

Docker faciliates the creation, management and execution of containers. Whilst not strictly necessary to support deployment to an existing/managed Kubernetes cluster, it can nevertheless be useful to have local access to the docker tooling. For example, if minikube is used to follow this guide using a local k8s cluster, then this is best achieved using minikube's docker driver.

Docker is most easily installed with...
```
curl -fsSL https://get.docker.com | sh
```

For convenience, add your user to the `docker` group...
```
sudo usermod -aG docker ${USER}
```

Logout/in to refresh your session's group permissions.

## kubectl

Kubectl is the main tool for interaction with a Kubernetes cluster. The latest version can be installed with...
```
mkdir -p $HOME/.local/bin \
&& curl -fsSLo $HOME/.local/bin/kubectl "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
&& chmod +x $HOME/.local/bin/kubectl
```

See the [official kubectl installation documentation](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) for more installation options.

## helm

Helm is the Kubernetes package manager, in which components are deployed to a Kubernetes cluster via helm charts. The helm charts are instantiated for deployment via 'values' that configure the chart templates.

The latest helm version can be installed with...
```
export HELM_INSTALL_DIR="$HOME/.local/bin" \
&& curl -sfL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
```

See the [official helm installation documentation](https://helm.sh/docs/intro/install/) for more installation options.

## minikube

Minikube is a tool that allows to create a local (single-node) Kubernetes cluster for development/testing. It is not designed for production use. In the absence of access to a 'full' Kubernetes cluster, this guide can be followed using minikube.

The latest version of minikube can be installed with...
```
mkdir -p $HOME/.local/bin \
&& curl -fsSLo $HOME/.local/bin/minikube "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64" \
&& chmod +x $HOME/.local/bin/minikube
```

See the [official minikube installation documentation](https://minikube.sigs.k8s.io/docs/start/) for more installation options.
