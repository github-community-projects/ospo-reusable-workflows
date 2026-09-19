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
      # Read the release version from a file instead of resolving it from PR
      # labels. Path is relative to the repository root. Default is empty.
      version-file: ""
      # yq expression that selects the version inside version-file, for example
      # .version for package.json. Leave empty for a plain-text file. Default is empty.
      version-key: ""
    secrets:
      github-token: ${{ secrets.GITHUB_TOKEN }}
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

## Jobs

1. **draft** - Evaluates release conditions, creates a draft release via release-drafter, and pushes the full and major version git tags (via [release-draft.yaml](../.github/workflows/release-draft.yaml)).
2. **publish** - Publishes the draft release when `publish` is true (via [release-publish.yaml](../.github/workflows/release-publish.yaml)).

## Announcement discussion

To create a GitHub Discussions announcement after the release publishes, chain the [Release Discussion workflow](release-discussion.md) on this workflow's outputs.
