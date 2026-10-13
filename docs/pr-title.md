# PR Title Reusable Workflow

## Triggering

Call the workflow on `pull_request`. It only reads the pull request title, so the read-only token that fork pull requests get is enough. Avoid `pull_request_target`: it hands a write token to runs for fork pull requests, and OSPS Baseline scanners flag it under OSPS-BR-01.03.

```yaml
on:
  pull_request:
    types: [opened, reopened, edited, synchronize]
```

## Inputs

```yaml
- uses: github-community-projects/ospo-reusable-workflows/.github/workflows/pr-title.yaml@main
  permissions:
    contents: read
    pull-requests: read
    statuses: write
  with:
    # Configure which types are allowed (newline-delimited).
    # From: https://github.com/commitizen/conventional-commit-types/blob/master/index.json
    # listing all below
    types: |
      build
      chore
      ci
      docs
      feat
      fix
      perf
      refactor
      revert
      style
      test
    scopes: |
      ci
      docs
    requireScope: true
  secrets:
    # The GitHub token to use
    github-token: ${{ secrets.GITHUB_TOKEN }}
```

## Outputs

None
