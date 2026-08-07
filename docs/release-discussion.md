# Release Discussion Reusable Workflow

Creates a GitHub Discussions announcement for a published release. Chain this workflow after any release variant workflow ([release-minimal](release-minimal.md), [release-goreleaser](release-goreleaser.md), [release-container](release-container.md)) using that workflow's outputs. This keeps `discussions: write` scoped to the discussion job only instead of forcing it on the whole release workflow.

The consolidated [release.yaml](release.md) has discussion creation built in; use this workflow with the slimmer variants.

## Usage

```yaml
jobs:
  release:
    permissions:
      contents: write # Create releases and push tags
      pull-requests: read # Read PR labels for release-drafter
    uses: github-community-projects/ospo-reusable-workflows/.github/workflows/release-minimal.yaml@main
    with:
      release-config-name: release-drafter.yml
    secrets:
      github-token: ${{ secrets.GITHUB_TOKEN }}

  discussion:
    needs: release
    # Only announce when a release was actually published
    if: ${{ needs.release.outputs.published == 'true' }}
    permissions:
      contents: read # Required by harden-runner
      discussions: write # Create announcement discussions
    uses: github-community-projects/ospo-reusable-workflows/.github/workflows/release-discussion.yaml@main
    with:
      full-tag: ${{ needs.release.outputs.full-tag }}
      body: ${{ needs.release.outputs.body }}
    secrets:
      github-token: ${{ secrets.GITHUB_TOKEN }}
      discussion-repository-id: ${{ secrets.DISCUSSION_REPOSITORY_ID }}
      discussion-category-id: ${{ secrets.DISCUSSION_CATEGORY_ID }}
```

The workflow skips gracefully (with a notice, not a failure) when the discussion IDs are empty or when Discussions are not enabled on the target repository.

## Getting the discussion IDs

Use the GitHub CLI (gh) with the following GraphQL query (replace `OWNER` and `REPO` with the appropriate values):

```
gh api graphql -f query='
  query($owner: String!, $repo: String!) {
    repository(owner: $owner, name: $repo) {
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
' -f owner='OWNER' -f repo='REPO'
```

Store the repository `id` as the `DISCUSSION_REPOSITORY_ID` secret and the chosen category `id` as the `DISCUSSION_CATEGORY_ID` secret.
