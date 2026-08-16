# Release Container Reusable Workflows

Creates a draft release via release-drafter, pushes the full and major version git tags, builds and pushes a multi-platform Docker image tagged `latest`, the full tag, and the short tag, and publishes the release. The draft-first pattern supports repositories with **immutable releases** enabled.

Two variants:

- `release-container.yaml` - build and push only, no attestation
- `release-container-attest.yaml` - additionally creates a build provenance attestation for the pushed image. Attestation is always on in this variant; it is skipped automatically with a warning on private repositories where attestation is not available.

## Usage

Without attestation:

```yaml
jobs:
  release:
    permissions:
      contents: write # Create releases and push tags
      pull-requests: read # Read PR labels for release-drafter
      packages: write # Push container images
    uses: github-community-projects/ospo-reusable-workflows/.github/workflows/release-container.yaml@main
    with:
      # The name of the configuration file to use
      # from the release-drafter/release-drafter GitHub Action
      release-config-name: release-drafter.yml
      # Image name, usually owner/repository (required)
      image-name: ${{ github.repository }}
      # Container registry URL, default is ghcr.io
      image-registry: ghcr.io
      # Container registry username, default is github.actor
      image-registry-username: ${{ github.actor }}
      # Comma-separated list of target platforms, default is linux/amd64,linux/arm64
      image-platforms: linux/amd64,linux/arm64
      # Publish the release after all jobs complete. Default is true.
      publish: true
      # Only release when the 'release' label is on the PR. Default is false.
      release-only-with-label: false
    secrets:
      github-token: ${{ secrets.GITHUB_TOKEN }}
      # Container registry password (required)
      image-registry-password: ${{ secrets.GITHUB_TOKEN }}
```

With attestation, use `release-container-attest.yaml` instead (same inputs and secrets) and grant two additional permissions:

```yaml
    permissions:
      contents: write # Create releases and push tags
      pull-requests: read # Read PR labels for release-drafter
      packages: write # Push container images
      id-token: write # Federate via Workload Identity for attestation
      attestations: write # Create build provenance attestation
    uses: github-community-projects/ospo-reusable-workflows/.github/workflows/release-container-attest.yaml@main
```

## Outputs

- full-tag: The full tag of the release (v1.0.0)
- short-tag: The short tag of the release (v1)
- body: The body of the release
- published: 'true' when the release was published; empty when no release happened or publish is false

## Announcement discussion

To create a GitHub Discussions announcement after the release publishes, chain the [Release Discussion workflow](release-discussion.md) on this workflow's outputs.
