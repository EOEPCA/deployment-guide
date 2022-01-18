# Helper Scripts

As a companion to the Deployment Guide descriptions, we have developed a set of scripts to provide a demonstration of an example deployment, in the subdirectory `deployment-guide/local-deploy` of the source repository for this guide...

```
git clone https://github.com/EOEPCA/deployment-guide \
&& cd deployment-guide \
&& ls local-deploy
```

The script `local-deploy/eoepca/eoepca.sh` acts as an entry-point to the full system deployment. In order to tailor the deployment for your target environment, The script is configured through environment variables and command-line arguments. By default the script assumes deployment to a local minikube.

Based upon our development experiences on CREODIAS, there is a wrapper script `creodias` with particular customisations suited to the CREODIAS infrastructure.

**COMING SOON...**<br>
Full description of how to make a local deployment using the helper scripts.
