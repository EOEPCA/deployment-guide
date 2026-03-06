# EOEPCA Deployment Guide

_See [latest published version](https://eoepca.readthedocs.io/projects/deploy/en/latest/)_

This repository contains two related deliverables that are released together:

- `docs/`: the Deployment Guide content rendered with MkDocs.
- `scripts/`: deployment helper scripts for EOEPCA+ Building Blocks.

A tagged release in this repository represents a consistent version of both.

## Release Versioning

Releases follow Semantic Versioning with repository tags in the form `eoepca-MAJOR.MINOR` (optionally `eoepca-MAJOR.MINOR.PATCH`).

For example, `Release 2.0` is tagged as `eoepca-2.0`.

- `MAJOR`: breaking deployment/script behavior changes.
- `MINOR`: backward-compatible capabilities or guidance additions.
- `PATCH`: backward-compatible fixes and clarifications.

The full policy is documented in [docs/release-versioning.md](docs/release-versioning.md).

## Documentation Publication

The guide is written in Markdown and rendered through [`mkdocs`](https://www.mkdocs.org/), with site configuration in `mkdocs.yml`.

Published documentation is served via Read the Docs:

- `latest` tracks `main`.
- Tagged releases provide versioned documentation views.

## Material Theme

The documentation is rendered with the [Material Theme](https://squidfunk.github.io/mkdocs-material/).

To avoid the need for a local installation of the mkdocs tooling and the Material for MkDocs theme, we have some local helper scripts that use a [docker image `squidfunk/mkdocs-material`](https://hub.docker.com/r/squidfunk/mkdocs-material) for this tooling.

## Helper Script - `serve`

The script `./serve` is used for local development of the docs - using the `squidfunk/mkdocs-material` docker image to invoke a local server to render the 'live' content from the `docs/` subdirectory.

The local document is served from http://localhost:8000/.
