# Federated Data Proxy Building Block

!!! info "Coming Soon"
    This Building Block is under active development and is not yet available for deployment via this guide. The proxy and control-plane components are currently only published to a private container registry. This page will be extended with full deployment instructions once public images/charts are available.

## Introduction

The Federated Data Proxy provides a unified access layer that lets a platform serve Earth Observation data from multiple internal and external providers transparently to end-users - regardless of whether the data is locally hosted, archived, or retrieved on demand from an upstream source.

It builds on the [Data Gateway](data-gateway.md) (EODAG), using it to resolve and retrieve assets from upstream providers on the platform's behalf.

## Key Functionality

- **Unified STAC catalogue**: asset URLs in the platform's STAC catalogue point at the proxy rather than upstream providers, keeping retrieval transparent to clients.
- **Online cache**: an optional caching layer (e.g. S3-backed) reduces repeated retrieval from upstream providers, with configurable retention (permanent, rolling-window, or LRU).
- **Access middleware**: a central endpoint that interfaces with each upstream provider, deciding whether to redirect, retrieve synchronously, or handle a request asynchronously.
- **IAM integration**: requests are authenticated against the platform IAM, with pre-signed URLs generated for protected object storage so users don't need to manage upstream credentials directly.
- **Optional QoS brokering**: rate/bandwidth limiting per user or group.

## Further Resources

- [EOEPCA Federated Data Proxy Reference Architecture](https://github.com/EOEPCA/system-architecture/blob/feature/federated-data-proxy/docs/reference-architecture/federated-data-proxy-BB.md) - architectural design and integration patterns
- [eodag-download-proxy](https://github.com/alambare/eodag-download-proxy) - source code for the proxy and control-plane components
- [Data Gateway Building Block](data-gateway.md) - the EODAG-based gateway this BB builds on
