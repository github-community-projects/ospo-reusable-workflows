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
      # Path to the Dockerfile, default is ./Dockerfile
      image-dockerfile: ./Dockerfile
      # Newline-separated Docker build arguments in KEY=VALUE form, passed
      # to the Docker build via docker/build-push-action build-args.
      # Default is none. Useful for baking build metadata into the image,
      # e.g. the commit SHA. Do not use build args for secrets; they can be
      # exposed in build logs and image history.
      image-build-args: |
        GIT_COMMIT=${{ github.sha }}
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
- The value must be a bare semver: `1.2.3` or `1.2.3-rc.1`. Build metadata (`1.2.3+build`) is rejected because release-drafter's version template drops it and Docker image tags cannot contain `+`. A leading `v` and surrounding whitespace are stripped. The `tag-template` and `name-template` in the release-drafter config still apply, so `v$RESOLVED_VERSION` produces `v1.2.3`.
- The job fails when the file is missing, the key does not match, or the value is not semver.
- Reading a structured file needs `yq` on the runner. `ubuntu-latest` ships it.
- Trigger labels (`release`, `breaking`, `feature`, `vuln`) still decide *whether* to release. Version-resolver labels (`major`, `minor`, `patch`) are ignored for the version.
- Independent of `version-file`, the workflow now checks the tag release-drafter resolved before pushing. If that tag already exists at another commit, the job fails instead of moving it, so a merge without a version bump cannot overwrite a release. A tag that already points at the release commit is allowed so a failed run can be retried. The major tag (`v1`) is still moved on every release.
- The scripts behind these checks live in [`scripts/`](../scripts/) with bats tests; the workflows embed a copy that CI keeps in sync.

## Outputs

- full-tag: The full tag of the release (v1.0.0)
- short-tag: The short tag of the release (v1)
- body: The body of the release
- published: 'true' when the release was published; empty when no release happened or publish is false

## Announcement discussion

To create a GitHub Discussions announcement after the release publishes, chain the [Release Discussion workflow](release-discussion.md) on this workflow's outputs.
