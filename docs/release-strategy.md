# Release Strategy

EOEPCA+ is formally released via the Deployment Guide, which baselines a set of Building Blocks versions that are validated as a coherent integration. The release baselines the following artifacts:

- Deployment Guide:
    - `docs/`: deployment guidance published via Read the Docs.
    - `scripts/`: helper automation used to deploy EOEPCA+ Building Blocks and related release artifacts.
    - `notebooks/`: executable validation and demonstration notebooks aligned with the documented deployment behavior.
- Tutorials (validation)<br>
  Configured in `EOEPCA/eoepca-killercoda`: scenario-driven hands-on flows that should match the same release capabilities.

For each tagged release, these artifacts are expected to describe and validate the same EOEPCA+ platform behavior.

## Versioning Numbering

The versioning numbering approach is described in the [EOEPCA+ Release Strategy](https://github.com/EOEPCA/.github/blob/main/profile/RELEASE-STRATEGY.md#version-numbering).

## Source of Truth

- `main` is the integration branch for ongoing work.
- Git tags (for example `eoepca-2.0` or `eoepca-2.1.3`) are the immutable release points.
- `docs/changelog.md` records release highlights and notable upgrade context.

## Documentation Publishing

Documentation is published via Read the Docs.

- `latest` tracks the `main` branch (development view).
- Versioned docs are built from release tags.
- Read the Docs `stable` is expected to be sourced from git tag `stable`.

## Release Process (Recommended)

The release cycle is described in the [EOEPCA+ Release Strategy](https://github.com/EOEPCA/.github/blob/main/profile/RELEASE-STRATEGY.md#release-cycle).

Such releases are prepared and published with the following recommended steps:

1. Prepare release content across `docs/`, `scripts/`, and `notebooks/`, and identify required tutorial updates in `EOEPCA/eoepca-killercoda`.
2. Validate deployment scripts and walkthroughs for affected Building Blocks.
3. Validate notebooks relevant to changed functionality.
4. Verify corresponding tutorials are aligned with the same release behavior.
5. Update `docs/changelog.md` with release notes.
6. Create and push an annotated tag `eoepca-X.Y` (or `eoepca-X.Y.Z` when patch granularity is needed), for example `git tag -a -m "EOEPCA+ Release X.Y" eoepca-X.Y`.
7. Verify Read the Docs built the tagged documentation version.
8. Announce release with links to the tag, docs version, and aligned tutorial material.

This process ensures that each release is a coherent and validated snapshot of the EOEPCA+ platform, with clear documentation and aligned learning resources.
