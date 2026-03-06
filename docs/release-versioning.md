# Release Versioning Strategy

This repository release represents an EOEPCA+ manifest release and is validated as a coherent set across:

- `docs/`: deployment guidance published via Read the Docs.
- `scripts/`: helper automation used to deploy EOEPCA+ Building Blocks and related release artifacts.
- `notebooks/`: executable validation and demonstration notebooks aligned with the documented deployment behavior.
- Tutorials configured in `EOEPCA/eoepca-killercoda`: scenario-driven hands-on flows that should match the same release capabilities.

For each tagged release, these artifacts are expected to describe and validate the same EOEPCA+ platform behavior.

## Versioning Model

Releases follow Semantic Versioning for version semantics, with repository tags in the form `eoepca-MAJOR.MINOR` (optionally `eoepca-MAJOR.MINOR.PATCH` when patch granularity is required).

Human-readable release labels map directly to this tag namespace. For example, `Release 2.0` corresponds to git tag `eoepca-2.0`.

- `MAJOR`: reserved for exceptional release boundaries, typically driven by significant architecture change or contractual/programmatic phasing.<br>
  Typical triggers include:
    - Platform architecture transitions that redefine how EOEPCA+ is composed or operated.
    - Contractual/programmatic phase transitions that require a clearly separated release line.
    - Broad migration expectations across multiple Building Blocks and dependent artifacts.
    - Intentional reset of compatibility expectations at EOEPCA+ release level.

- `MINOR`: use for backward-compatible capability growth across the platform release.<br>
  Typical triggers include:
    - New Building Block coverage, new deployment paths, or new optional features.
    - Backward-compatible integration of sub-component feature releases.
    - Material operational improvements that do not require migration.
    - Significant new guidance enabling new supported usage patterns.

- `PATCH`: use for backward-compatible corrections without capability expansion.<br>
  Typical triggers include:
    - Script fixes, reliability/stability fixes, and safe configuration corrections.
    - Documentation corrections and clarification updates.
    - Backward-compatible sub-component bugfix rollups.

Because this repository is the umbrella release vehicle for EOEPCA+, release numbering is decided at repository level, not per single sub-component or artifact.

`MAJOR` is not an automatic outcome of a single breaking change in one component; it is an explicit release decision at EOEPCA+ program level.

For routine rollups, use this default rule:

- If release scope introduces new features/use cases/components, the repository release is typically `MINOR`.
- Else, if release scope is limited to backward-compatible fixes, the repository release is `PATCH`.
- Escalate to `MAJOR` only when architecture or contractual phasing criteria are met.

This means fixes and features from individual sub-components, notebooks, and tutorials are rolled up into one EOEPCA+ manifest release through this repository tag.

Pre-releases should use standard SemVer pre-release suffixes in the same namespace, for example `eoepca-2.1.0-rc.1`.

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

1. Prepare release content across `docs/`, `scripts/`, and `notebooks/`, and identify required tutorial updates in `EOEPCA/eoepca-killercoda`.
2. Validate deployment scripts and walkthroughs for affected Building Blocks.
3. Validate notebooks relevant to changed functionality.
4. Verify corresponding tutorials are aligned with the same release behavior.
5. Update `docs/changelog.md` with release notes.
6. Create and push an annotated tag `eoepca-X.Y` (or `eoepca-X.Y.Z` when patch granularity is needed), for example `git tag -a -m "EOEPCA+ Release X.Y" eoepca-X.Y`.
7. Verify Read the Docs built the tagged documentation version.
8. Announce release with links to the tag, docs version, and aligned tutorial material.

## Release Preparation Baseline And Delta

Each release is prepared by establishing a baseline for the composing Building Blocks (BBs), similar to a feature-freeze point.

- Baseline definition: record the BB versions/commits and associated deployment assumptions that form the intended release candidate.
- Delta assessment: compare this baseline with the previous EOEPCA+ release baseline to identify the required update set.
- Rollup selection: include only the validated and release-ready subset of BB developments in the repository release.

This process is typically run as a calendar-aligned rollup, with releases targeted approximately quarterly.

Quarterly rollups are typically expected to result in a `MINOR` release, reflecting the addition of new features, new use cases, and potentially new components.

The right is reserved to issue `PATCH` releases between quarterly rollups when backward-compatible fixes are needed.

## Compatibility Guidance

As part of the baseline-to-baseline delta assessment, document compatibility impact explicitly:

- Required migration actions.
- State/configuration key changes (`~/.eoepca/state`).
- Any ordering or dependency changes between Building Blocks.

If migration effort is non-trivial, treat the change as `MAJOR` and include a dedicated migration section in the changelog.
