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
      # Read the release version from a file instead of resolving it from PR
      # labels. Path is relative to the repository root. Default is empty.
      version-file: ""
      # yq expression that selects the version inside version-file, for example
      # .version for package.json. Leave empty for a plain-text file. Default is empty.
      version-key: ""
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

## Version from a file

Set `version-file` to read the release version from a file in the repository instead of resolving it from PR labels. Set `version-key` to a [yq](https://mikefarah.gitbook.io/yq/) expression when the file is JSON, YAML, or TOML; leave it empty when the file contains only the version.

| File | `version-file` | `version-key` |
| ---- | -------------- | ------------- |
| `VERSION` (plain text) | `VERSION` | |
| `package.json` | `package.json` | `.version` |
| `Chart.yaml` | `Chart.yaml` | `.version` |
| `pyproject.toml` | `pyproject.toml` | `.project.version` |

Behavior:

- The file is read from the base branch after the PR is merged, so bump the version in the same PR that is labeled `release`.
- The value must be a bare semver (`1.2.3`, with an optional prerelease or build suffix). A leading `v` and surrounding whitespace are stripped. The `tag-template` and `name-template` in the release-drafter config still apply, so `v$RESOLVED_VERSION` produces `v1.2.3`.
- The job fails when the file is missing, the value is not semver, or a tag for that version already exists. This prevents a duplicate release when the version was not bumped.
- Trigger labels (`release`, `breaking`, `feature`, `vuln`) still decide *whether* to release. Version-resolver labels (`major`, `minor`, `patch`) are ignored for the version.

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
