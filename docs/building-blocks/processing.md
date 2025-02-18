# Processing - OGC API Processes Engine

The **Processing Building Block** provides deployment and execution of user-defined processing workflows within the EOEPCA+ platform - with support for OGC API Processes, OGC Application Packages and openEO. The Processing BB is deployed in the form of a number of _Processing Engine_ variants that implements different workflow approaches:

* [**OGC API Processes Engine**](./oapip-engine.md)<br>
  The **OGC API Processes Engine** provides an OGC API Processes execution engine through which users can deploy, manage, and execute OGC Application Packages. The OAPIP engine is provided by the [ZOO-Project](https://zoo-project.github.io/docs/intro.html#what-is-zoo-project) `zoo-project-dru` implementation - supporting OGC WPS 1.0.0/2.0.0 and OGC API Processes Parts 1 & 2.
* [**openEO Engine**](./openeo-engine.md)<br>
  The openEO engine provides an API that allows users to connect to Earth observation cloud back-ends in a simple and unified way. The openEO engine is provided by the [OpenEO Geopyspark Driver](https://github.com/Open-EO/openeo-geopyspark-driver).
