
# HostPath Provisioner for Local Development/Testing

If you already have a storage class that you would like to use, you can skip this section.

> This is not advised for production environments. We advise you to follow the [Resources for Setting Up Storage Classes](./storage-classes.md#resources-for-setting-up-storage-classes) for production environments. 


For a solution to support development/testing environments, the HostPath provisioner can be used - noting that this can only be used for single node deployments. 

---

1. Deploy the provisioner and its associated `standard` storage class.

```bash
kubectl apply -f https://raw.githubusercontent.com/EOEPCA/eoepca-plus/refs/heads/deploy-develop/argocd/infra/storage/hostpath-provisioner.yaml
```

2. Monitor the deployment.

```bash
kubectl get -n kube-system sc/standard pod/hostpath-storage-provisioner
```

---

This will now give you a storage class called `standard` that can be used for deployment of the EOEPCA+ Building Blocks that require persistent storage.