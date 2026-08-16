# Release Minimal Reusable Workflow

Creates a draft release via release-drafter, pushes the full and major version git tags, and publishes the release. No artifact builds. This is the right variant for repositories that only need release-drafter + tagging (for example, GitHub Action repositories).

The draft-first pattern supports repositories with **immutable releases** enabled.

## Usage

```yaml
jobs:
  release:
    permissions:
      contents: write # Create releases and push tags
      pull-requests: read # Read PR labels for release-drafter
    uses: github-community-projects/ospo-reusable-workflows/.github/workflows/release-minimal.yaml@main
    with:
      # The name of the configuration file to use
      # from the release-drafter/release-drafter GitHub Action
      release-config-name: release-drafter.yml
      # Publish the release after all jobs complete. When false, the release
      # remains a draft for manual review. Default is true.
      publish: true
      # Only release when the 'release' label is on the PR. When true,
      # other trigger labels (breaking, feature, vuln) are ignored. Default is false.
      release-only-with-label: false
    secrets:
      github-token: ${{ secrets.GITHUB_TOKEN }}
```

## Outputs

- full-tag: The full tag of the release (v1.0.0)
- short-tag: The short tag of the release (v1)
- body: The body of the release
- published: 'true' when the release was published; empty when no release happened or publish is false

## Jobs

1. **draft** - Evaluates release conditions, creates a draft release via release-drafter, and pushes the full and major version git tags (via [release-draft.yaml](../.github/workflows/release-draft.yaml)).
2. **publish** - Publishes the draft release when `publish` is true (via [release-publish.yaml](../.github/workflows/release-publish.yaml)).

## Announcement discussion

To create a GitHub Discussions announcement after the release publishes, chain the [Release Discussion workflow](release-discussion.md) on this workflow's outputs.
