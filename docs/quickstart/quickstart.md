# Quickstart

The deployment of the EOEPCA components and the supporting Kubernetes cluster is described in the sections [**Cluster**](../cluster/prerequisite-tooling.md) and [**EOEPCA**](../eoepca/persistence.md). These sections should be consulted for more detailed information.

### **Scripted Deployment**

As a companion to these descriptions, we have developed a set of scripts to provide a demonstration of an example deployment. This is described in the following section [Scripted Deployment](scripted-deployment.md).

> **NOTE that the scripted deployment assumes that installation of the [Prerequisite Tooling](../cluster/prerequisite-tooling.md) has been performed.**

### **Customised Deployments**

The Scripted Deployment can be quickly exploited through the following customisations for particular use cases:

* **[Simple](simple-deployment.md)**<br>
  _Basic local deployment_
* **[Processing](processing-deployment.md)**<br>
  _Deployment focused on processing_
* **[Data Access](data-access-deployment.md)**<br>
  _Deployment focused on the Resource Catalogue and Data Access services_
* **[Exploitation](exploitation-deployment.md)**<br>
  _Deployment providing deployment/execution of processing via the ADES, supported by Resource Catalogue and Data Access services_
* **[User Management](userman-deployment.md)**<br>
  _Deployment focused on the User Management services_
* **[CREODIAS](creodias-deployment.md)**<br>
  _Deployment with access to CREODIAS EO data_

Each customisation is introduced in their respective sections.

### **Quick Example**

Follow these steps to create a simple local deployment in minikube...

1. **Prerequisite Tooling**<br>
   Follow the steps in section [Prerequisite Tooling](../cluster/prerequisite-tooling.md) to install the required tooling.
2. **Clone the repository**<br>
   `git clone https://github.com/EOEPCA/deployment-guide`
3. **Initiate the deployment**<br>
   `cd deployment-guide`<br>
   `./deploy/simple/simple`
4. **Wait for deployment ready**<br>
     1. List pod status<br>
        `watch kubectl get pod -A`<br>
     1. Wait until all pods report either `Running` or `Completed`<br>
        _This may take 10-20 mins depending on the capabilities of your platform._
5. **Test the deployment**<br>
   Make the [sample requests](./processing-deployment.md#example-requests-snuggs-application) to the ADES processing service.

The sample processing requests offered in [Processing Deployment](./processing-deployment.md#example-requests-snuggs-application) assume use of the Visual Studio Code (vscode) extension [REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client). **_Alternatively, the following `curl` commands can be used instead..._**

**List Processes**

```
curl -k \
  --request GET \
  --url https://ades-open.192.168.49.2.nip.io/eric/wps3/processes \
  --header 'accept: application/json'
```

**Deploy Process**

```
curl -k \
  --request POST \
  --url https://ades-open.192.168.49.2.nip.io/eric/wps3/processes \
  --header 'accept: application/json' \
  --header 'content-type: application/json' \
  --data '{"executionUnit": {"href": "https://raw.githubusercontent.com/EOEPCA/app-snuggs/main/app-package.cwl","type": "application/cwl"}}'
```

**Get Process Details**

```
curl -k \
  --request GET \
  --url https://ades-open.192.168.49.2.nip.io/eric/wps3/processes/snuggs-0_3_0 \
  --header 'accept: application/json'
```

**Execute Process**

```
curl -k -v \
  --request POST \
  --url https://ades-open.192.168.49.2.nip.io/eric/wps3/processes/snuggs-0_3_0/execution \
  --header 'accept: application/json' \
  --header 'content-type: application/json' \
  --header 'prefer: respond-async' \
  --data '{"inputs": {"input_reference":  "https://earth-search.aws.element84.com/v0/collections/sentinel-s2-l2a-cogs/items/S2B_36RTT_20191205_0_L2A","s_expression": "ndvi:(/ (- B05 B03) (+ B05 B03))"},"response":"raw"}'
```

**Get Job Status**

This request requires the `Location` header from the response to the execute request. This will be of the form `/{user}/wps3/jobs/{job-id}` - e.g. `/eric/wps3/jobs/7b58bc38-64d4-11ed-b962-0242ac11000e`.

```
curl -k \
  --request GET \
  --url https://ades-open.192.168.49.2.nip.io{location-header} \
  --header 'accept: application/json'
```

**Get Job Results**

This request uses the same URL as `Get Job Status`, with the additional URL path `/result` - i.e. `/{user}/wps3/jobs/{job-id}/result` - e.g. `/eric/wps3/jobs/7b58bc38-64d4-11ed-b962-0242ac11000e/result`

```
curl -k \
  --request GET \
  --url https://ades-open.192.168.49.2.nip.io{location-header}/result \
  --header 'accept: application/json'
```

** List Jobs**

```
curl -k \
  --request GET \
  --url https://ades-open.192.168.49.2.nip.io/eric/wps3/jobs \
  --header 'accept: application/json'
```
