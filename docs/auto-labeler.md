# Auto-labeler Reusable Workflow

## Triggering

Call the workflow on `pull_request` and skip pull requests from forks. Avoid `pull_request_target`: it hands a write token to runs for fork pull requests, and OSPS Baseline scanners flag it under OSPS-BR-01.03.

```yaml
on:
  pull_request:
    types: [opened, reopened, edited, synchronize]
jobs:
  auto_labeler:
    # Fork pull requests get a read-only token and cannot be labeled.
    if: github.event.pull_request.head.repo.full_name == github.repository
    permissions:
      contents: read
      pull-requests: write
      issues: write
    uses: github-community-projects/ospo-reusable-workflows/.github/workflows/auto-labeler.yaml@main
    with:
      config-name: release-drafter.yml
    secrets:
      github-token: ${{ secrets.GITHUB_TOKEN }}
```

Label pull requests from forks by hand before merging. The [release workflows](release.md) read labels when the pull request merges, so a label added by hand drives release notes and version bumps the same way.

## Inputs

```yaml
- uses: github-community-projects/ospo-reusable-workflows/.github/workflows/auto-labeler.yaml@main
  permissions:
    contents: read # Read the autolabeler config
    pull-requests: write # Apply labels to the pull request
    issues: write # Auto-create labels missing from the repository
  with:
    # The name of the configuration file to use, default is release-drafter.yml
    # from the release-drafter/release-drafter GitHub Action
    config-name: release-drafter.yml
  secrets:
    # The GitHub token to use
    github-token: ${{ secrets.GITHUB_TOKEN }}
```

## Outputs

None

## Missing labels

If the autolabeler config references a label that does not exist in the repository, GitHub creates it automatically while applying it. This is why the workflow requires `issues: write`; the labels API is part of the Issues API.

Auto-created labels get a default color and no description. If you care about label colors or descriptions, pre-create the labels (for example with the [Labeler workflow](labeler.md)) and the auto-labeler will use them as-is.

> [!IMPORTANT]
> `issues: write` became required in v2.0.0. Callers referencing `@main` receive this change as soon as it merges and must add the grant to their permissions block immediately. Callers pinned to v1 must add it when they upgrade to v2. Without the grant the workflow fails at startup with "The nested job 'main' is requesting 'issues: write', but is only allowed 'issues: none'".
