# Release GoReleaser Reusable Workflows

Creates a draft release via release-drafter, pushes the full and major version git tags, builds Go binaries with GoReleaser, uploads the artifacts to the draft release, and publishes the release. The draft-first pattern supports repositories with **immutable releases** enabled.

Two variants:

- `release-goreleaser.yaml` - build and upload only, no attestation
- `release-goreleaser-attest.yaml` - additionally creates build provenance attestations for all artifacts and SBOM (Software Bill of Materials) attestations per archive. Attestation is always on in this variant; it is skipped automatically with a warning on private repositories where attestation is not available.

## Usage

Without attestation:

```yaml
jobs:
  release:
    permissions:
      contents: write # Create releases, push tags, upload release assets
      pull-requests: read # Read PR labels for release-drafter
    uses: github-community-projects/ospo-reusable-workflows/.github/workflows/release-goreleaser.yaml@main
    with:
      # The name of the configuration file to use
      # from the release-drafter/release-drafter GitHub Action
      release-config-name: release-drafter.yml
      # Path to GoReleaser config file (required)
      goreleaser-config-path: .goreleaser.yaml
      # Path to go.mod or go.work file for Go version detection, default is go.mod
      go-version-file: go.mod
      # Publish the release after all jobs complete. Default is true.
      publish: true
      # Only release when the 'release' label is on the PR. Default is false.
      release-only-with-label: false
    secrets:
      github-token: ${{ secrets.GITHUB_TOKEN }}
```

With attestation, use `release-goreleaser-attest.yaml` instead (same inputs) and grant two additional permissions:

```yaml
    permissions:
      contents: write # Create releases, push tags, upload release assets
      pull-requests: read # Read PR labels for release-drafter
      id-token: write # Federate for attestation
      attestations: write # Generate artifact and SBOM attestations
    uses: github-community-projects/ospo-reusable-workflows/.github/workflows/release-goreleaser-attest.yaml@main
```

## Outputs

- full-tag: The full tag of the release (v1.0.0)
- short-tag: The short tag of the release (v1)
- body: The body of the release
- published: 'true' when the release was published; empty when no release happened or publish is false

## GoReleaser configuration

Your GoReleaser config **must** disable release and changelog management since this workflow handles both via release-drafter:

```yaml
release:
  disable: true

changelog:
  disable: true
```

Without these settings, GoReleaser will attempt to create its own GitHub release, conflicting with the draft release created by release-drafter. The workflow validates this and fails early if release is not disabled.

## SBOM generation

If your GoReleaser config includes an `sboms:` block that calls `syft`, the workflow detects it via `yq` and installs syft automatically before running GoReleaser. Generated `*.spdx.json` files are uploaded alongside the archives.

In the attest variant, the `attest_sboms` job additionally runs `actions/attest-sbom` per (archive, SBOM) pair. SBOM linkage requires GoReleaser to emit one SBOM per archive using the default `${artifact}.spdx.json` naming pattern (or any naming that strips `.spdx.json` to yield the matching archive path).

## Announcement discussion

To create a GitHub Discussions announcement after the release publishes, chain the [Release Discussion workflow](release-discussion.md) on this workflow's outputs.
