# Processing Deployment

A deployment wrapper script has been prepared for a 'processing' deployment - that is focused on the ADES and the deployment/execution of processing jobs.

The script [`deploy/processing/processing`](https://github.com/EOEPCA/deployment-guide/blob/main/deploy/processing/processing) achieves this by appropriate [configuration of the environment variables](scripted-deployment.md#environment-variables), before launching the [eoepca.sh deployment script](scripted-deployment.md#command-line-arguments). The deployment configuration is captured in the file [`deploy/processing/processing-options`](https://github.com/EOEPCA/deployment-guide/blob/main/deploy/processing/processing-options).

The processing deployment applies the following configuration:

* Assumes a public IP (which allows configuration of TLS)<br>
  _In case of no public IP then see section [Private Deployment](scripted-deployment.md#private-deployment)_
* TLS via letsencrypt
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

## Example Requests

The file [`deploy/samples/requests/processing/processing.http`](https://github.com/EOEPCA/deployment-guide/blob/main/deploy/samples/requests/processing/processing.http) has been prepared with sample requests for **_OGC API Processes_** operations:

* List Processes
* Deploy Process
* Get Process Details
* Execute Process
* Get Job Status
* Get Job Results

The file `requests.http` describes the HTTP requests for the ADES OGC API Processes endpoint, and is designed for use with the Visual Studio Code (vscode) extension [REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client). Install in vscode with `ext install humao.rest-client`.

The variables `@hostname` and `@domain` can be configured at the top of the file.

## Processing Results

In the default configuration, the processing results are pushed to the Minio S3 object storage - at the endpoint `minio-console.<domain>` - e.g. `http://minio-console.192.168.49.2.nip.io` - with default credentials `eoepca:changeme`.

The outputs are pushed as a static STAC catalogue to a path that includes the unique job ID.
