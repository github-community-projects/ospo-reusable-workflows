# Release Reusable Workflow

Consolidated release workflow that handles creating releases, optionally building/pushing Docker images, and optionally creating GitHub Discussions announcements.

## Inputs

```yaml
- uses: github-community-projects/ospo-reusable-workflows/.github/workflows/release.yaml@main
  permissions:
    contents: write
    pull-requests: read
    packages: write       # only needed if building images
    id-token: write       # only needed if creating attestations
    attestations: write   # only needed if creating attestations
    discussions: write    # only needed if creating discussions
  with:
    # Boolean flag whether to publish the release, default is true
    publish: true
    # The name of the configuration file to use
    # from the release-drafter/release-drafter GitHub Action
    release-config-name: release-drafter.yml
    # Boolean flag whether to update major tag to latest full semver tag, default is true
    update-major-tag: true

    # --- Optional: Docker image build/push ---
    # Setting image-name enables the image build/push job
    # Image name, usually owner/repository
    image-name: ${{ github.repository }}
    # Container registry URL, default is ghcr.io
    image-registry: ghcr.io
    # Container registry username, default is github.actor
    image-registry-username: ${{ github.actor }}
    # Comma-separated list of target platforms, default is linux/amd64,linux/arm64
    image-platforms: linux/amd64,linux/arm64
    # Flag to create a build provenance attestation, default is false
    create-attestation: true

  secrets:
    # The GitHub token to use (required)
    github-token: ${{ secrets.GITHUB_TOKEN }}
    # Container registry password (required when image-name is set)
    image-registry-password: ${{ secrets.GITHUB_TOKEN }}

    # --- Optional: GitHub Discussion announcement ---
    # Setting both discussion IDs enables the discussion creation job
    # GraphQL ID of the discussion category
    discussion-category-id: ${{ secrets.DISCUSSION_CATEGORY_ID }}
    # GraphQL ID of the repository for discussions
    discussion-repository-id: ${{ secrets.DISCUSSION_REPOSITORY_ID }}
```

## Outputs

- full-tag: The full tag of the release (v1.0.0)
- short-tag: The short tag of the release (v1)
- body: The body of the release, to be used in the GitHub release UI

```yaml
jobs:
  release:
  other_job:
    needs: release
    env:
      FULL_TAG: ${{ needs.release.outputs.full-tag }}
      SHORT_TAG: ${{ needs.release.outputs.short-tag }}
      BODY: ${{ needs.release.outputs.body }}
```

## Jobs

The workflow runs up to four jobs:

1. **create_release** - Always runs. Creates a release via release-drafter.
2. **update_major_tag** - Runs when `update-major-tag` is true. Force-updates the major version tag.
3. **release_image** - Runs when `image-name` is set. Builds and pushes a multi-platform Docker image.
4. **release_discussion** - Runs when both `discussion-category-id` and `discussion-repository-id` are set. Creates a GitHub Discussions announcement.

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
