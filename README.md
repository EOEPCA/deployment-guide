# EOEPCA Deployment Guide

The guide is written in Markdown and rendered through the [`mkdocs` tool](https://www.mkdocs.org/).

The file `mkdocs.yml` is the configuration file that describes the organisation and settings for the document generation.

## Material Theme

The documentation is rendered with the [Material Theme](https://squidfunk.github.io/mkdocs-material/).

To avoid the need for a local installation of the mkdocs tooling and the Material for MkDocs theme, we have some local helper scripts that use a [docker image `squidfunk/mkdocs-material`](https://hub.docker.com/r/squidfunk/mkdocs-material) for this tooling.

## Helper Script - `serve`

The script `./serve` is used for local development of the docs - using the `squidfunk/mkdocs-material` docker image to invoke a local server to render the 'live' content from the `docs/` subdirectory.

The local document is served from http://localhost:8000/.

## GitHub Action

The GitHub Action at `.github/workflows/main.yml` is triggered on each commit pushed to `origin/main` to build the documentation to the branch `gh-pages` from where it is published.

## Public Domain - deployment-guide.docs.eoepca.org

The contents of the `gh-pages` branch are published via the domain `deployment-guide.docs.eoepca.org`.

This is achieved by the steps:

1. Configure the GitHub pages to publish from the `gh-pages` branch and using the domain `deployment-guide.docs.eoepca.org`
2. Follow the GitHub steps to verify ownership of the domain `deployment-guide.docs.eoepca.org`
3. Maintain the file `docs/CNAME` with the domain name

## Helper Script - `publish` (DEPRECATED)

This script was used before the use of the GitHub Action to manually publish the document 'on-demand'.

It is no longer needed for this purpose - but is retained in case it proves useful.
