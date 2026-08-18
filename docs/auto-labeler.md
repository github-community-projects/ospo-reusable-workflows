# Auto-labeler Reusable Workflow

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
> `issues: write` became required in v2.0.0. Callers on v1 that upgrade must add it to their permissions block, or the workflow fails at startup with "The nested job 'main' is requesting 'issues: write', but is only allowed 'issues: none'".
