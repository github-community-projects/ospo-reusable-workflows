# Release Discussion Reusable Workflow

> [!CAUTION]
> This workflow has been deprecated and consolidated into the [Release workflow](release.md). Calling `release-discussion.yaml` directly will fail with an error. Migrate by setting the `discussion-category-id` and `discussion-repository-id` secrets on `release.yaml` instead.

## Migration

Replace your existing `release-discussion.yaml` call:

```yaml
# Before (deprecated)
release_discussion:
  needs: release
  uses: github-community-projects/ospo-reusable-workflows/.github/workflows/release-discussion.yaml@main
  with:
    full-tag: ${{ needs.release.outputs.full-tag }}
    body: ${{ needs.release.outputs.body }}
  secrets:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    discussion-repository-id: ${{ secrets.DISCUSSION_REPOSITORY_ID }}
    discussion-category-id: ${{ secrets.DISCUSSION_CATEGORY_ID }}
```

With the consolidated `release.yaml` secrets:

```yaml
# After
release:
  uses: github-community-projects/ospo-reusable-workflows/.github/workflows/release.yaml@main
  with:
    release-config-name: release-drafter.yaml
  secrets:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    discussion-category-id: ${{ secrets.DISCUSSION_CATEGORY_ID }}
    discussion-repository-id: ${{ secrets.DISCUSSION_REPOSITORY_ID }}
```

Key changes:
- `full-tag` and `body` no longer need to be passed — they are handled internally
- Discussion IDs moved from required secrets to optional secrets

See the full [Release workflow documentation](release.md) for all available inputs.

## Notes

To get the discussion repository ID and category ID, use the GitHub GraphQL API Explorer: https://docs.github.com/en/graphql/overview/explorer with the following query (replace `OWNER` and `REPO` with the appropriate values):

```graphql
query {
  repository(owner: "OWNER", name: "REPO") {
    id
    discussionCategories(first: 50) {
      nodes {
        id
        name
        slug
      }
    }
  }
}
```
