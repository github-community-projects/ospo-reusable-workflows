# Major Version Updater

> [!TIP]
> Pin the `uses:` line to a full commit SHA with a trailing version comment. See [Pinning to a SHA](../README.md#pinning-to-a-sha).

## Inputs

```yaml
- uses: github-community-projects/ospo-reusable-workflows/.github/workflows/major-version-updater.yaml@[latest sha here] # vX.Y.Z
  permissions:
    contents: write
  with:
    # Tag name that the major tag will point to (e.g. v1.2.3)
    tag-name: v1.2.3
  secrets:
    # The GitHub token to use
    github-token: ${{ secrets.GITHUB_TOKEN }}
```

## Outputs

None
