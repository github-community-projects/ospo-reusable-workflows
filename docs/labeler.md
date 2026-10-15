# Labeler Reusable Workflow

> [!TIP]
> Pin the `uses:` line to a full commit SHA with a trailing version comment. See [Pinning to a SHA](../README.md#pinning-to-a-sha).

## Triggering

Call the workflow on `pull_request` and skip pull requests from forks and Dependabot. Avoid `pull_request_target`: it hands a write token to runs for fork pull requests, and OSPS Baseline scanners flag it under OSPS-BR-01.03.

```yaml
on:
  pull_request:
    types: [opened, reopened, edited, synchronize]
jobs:
  labeler:
    # Fork and Dependabot pull requests get a read-only token and cannot be labeled.
    if: github.event.pull_request.head.repo.full_name == github.repository && github.actor != 'dependabot[bot]'
    permissions:
      contents: read
      pull-requests: write
    uses: github-community-projects/ospo-reusable-workflows/.github/workflows/labeler.yaml@main
    with:
      config-path: labeler.yml
    secrets:
      github-token: ${{ secrets.GITHUB_TOKEN }}
```

Label pull requests from forks and from Dependabot by hand before merging.

## Inputs

```yaml
- uses: github-community-projects/ospo-reusable-workflows/.github/workflows/labeler.yaml@main
  permissions:
    contents: read
    pull-requests: write
  with:
    # The name of the configuration file to use, default is labeler.yml
    # from the actions/labeler GitHub Action
    # Yaml file must end in .yml
    config-path: labeler.yml
  secrets:
    # The GitHub token to use
    github-token: ${{ secrets.github-token }}
```

## Outputs

None
