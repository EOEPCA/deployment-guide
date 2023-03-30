# Processing Deployment

A deployment wrapper script has been prepared for a 'processing' deployment - that is focused on the ADES and the deployment/execution of processing jobs.

The script [`deploy/processing/processing`](https://github.com/EOEPCA/deployment-guide/blob/main/deploy/processing/processing) achieves this by appropriate [configuration of the environment variables](scripted-deployment.md#environment-variables), before launching the [eoepca.sh deployment script](scripted-deployment.md#command-line-arguments). The deployment configuration is captured in the file [`deploy/processing/processing-options`](https://github.com/EOEPCA/deployment-guide/blob/main/deploy/processing/processing-options).

The processing deployment applies the following configuration:

* Assumes a private deployment - i.e. no external-facing IP/ingress, and hence no TLS<br>
  _To configure an external-facing deployment with TLS protection, then see section [Public Deployment](scripted-deployment.md#public-deployment)_
* No TLS for service ingress endpoints
* Services deployed:
    * ADES for processing
    * Minio for S3 object storage
* ADES stage-out to Minio
* Open ingress are enabled for unauthenticated access to ADES service
* Other eoepca services not deployed

## Initiate Deployment

Deployment is initiated by invoking the script...

```
./deploy/processing/processing
```

The ADES service is accessed at the endpoint `ades-open.<domain>` - e.g. `ades-open.192.168.49.2.nip.io`.

## Example Requests - `snuggs` application

The file [`deploy/samples/requests/processing/snuggs.http`](https://github.com/EOEPCA/deployment-guide/blob/main/deploy/samples/requests/processing/snuggs.http) has been prepared with sample requests for **_OGC API Processes_** operations:

* List Processes
* Deploy Process
* Get Process Details
* Execute Process
* Get Job Status
* Get Job Results

!!! note
    The first requests in the file provide optional calls to obtain a user ID token (`openidConfiguration` / `authenticate`).
    These are to be used in the case that protected (not 'open') endpoints are deployed.

The file describes the HTTP requests for the ADES OGC API Processes endpoint, and is designed for use with the Visual Studio Code (vscode) extension [REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client). Install in vscode with `ext install humao.rest-client`.

The variables `@hostname` and `@domain` can be configured at the top of the file.

??? example "Requests using CuRL"
    Alternatively, the following `curl` commands can be used instead...

    **List Processes**

    ```bash
    curl -k \
      --request GET \
      --url https://ades-open.192.168.49.2.nip.io/eric/wps3/processes \
      --header 'accept: application/json'
    ```

    **Deploy Process**

    ```bash
    curl -k \
      --request POST \
      --url https://ades-open.192.168.49.2.nip.io/eric/wps3/processes \
      --header 'accept: application/json' \
      --header 'content-type: application/json' \
      --data '{"executionUnit": {"href": "https://raw.githubusercontent.com/EOEPCA/app-snuggs/main/app-package.cwl","type": "application/cwl"}}'
    ```

    **Get Process Details**

    ```bash
    curl -k \
      --request GET \
      --url https://ades-open.192.168.49.2.nip.io/eric/wps3/processes/snuggs-0_3_0 \
      --header 'accept: application/json'
    ```

    **Execute Process**

    ```bash
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

    ```bash
    curl -k \
      --request GET \
      --url https://ades-open.192.168.49.2.nip.io{location-header} \
      --header 'accept: application/json'
    ```

    **Get Job Results**

    This request uses the same URL as `Get Job Status`, with the additional URL path `/result` - i.e. `/{user}/wps3/jobs/{job-id}/result` - e.g. `/eric/wps3/jobs/7b58bc38-64d4-11ed-b962-0242ac11000e/result`

    ```bash
    curl -k \
      --request GET \
      --url https://ades-open.192.168.49.2.nip.io{location-header}/result \
      --header 'accept: application/json'
    ```

    The response indicates the location of the results, which should be in the `minio` object storage. This can be checked via [browser access](https://minio-console.192.168.49.2.nip.io/) at https://minio-console.192.168.49.2.nip.io/, or using an S3 client such as...

    ```bash
    s3cmd -c ./deploy/cluster/s3cfg ls s3://eoepca
    ```

    ** List Jobs**

    ```bash
    curl -k \
      --request GET \
      --url https://ades-open.192.168.49.2.nip.io/eric/wps3/jobs \
      --header 'accept: application/json'
    ```

## Processing Results

In the default configuration, the processing results are pushed to the Minio S3 object storage - at the endpoint `minio-console.<domain>` - e.g. `http://minio-console.192.168.49.2.nip.io` - with default credentials `eoepca:changeme`.

The outputs are pushed as a static STAC catalogue to a path that includes the unique job ID.
