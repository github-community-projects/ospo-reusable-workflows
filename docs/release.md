# Release Reusable Workflow

Consolidated release workflow that creates a draft release, optionally builds artifacts (GoReleaser, Docker images), creates GitHub Discussions announcements, and publishes the release after all jobs succeed. This draft-first pattern supports repositories with immutable releases enabled.

## Inputs

```yaml
- uses: github-community-projects/ospo-reusable-workflows/.github/workflows/release.yaml@main
  permissions:
    contents: write
    pull-requests: read
    packages: write
    id-token: write
    attestations: write
    discussions: write
  with:
    # Publish the release after all jobs complete. When false, the release
    # remains a draft for manual review. Default is true.
    publish: true
    # The name of the configuration file to use
    # from the release-drafter/release-drafter GitHub Action
    release-config-name: release-drafter.yml

    # --- Optional: GoReleaser build/upload ---
    # Setting goreleaser-config-path enables the GoReleaser job
    # Path to GoReleaser config file (e.g., .goreleaser.yaml)
    goreleaser-config-path: .goreleaser.yaml
    # Path to go.mod or go.work file for Go version detection, default is go.mod
    go-version-file: go.mod

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
    # Flag to create build provenance attestations, default is false
    # Attestation is only available for public repositories. Private repos
    # will see a warning and skip attestation automatically.
    create-attestation: true
    create-discussion: true

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

The workflow runs up to six jobs:

1. **create_release** - Always runs. Creates a draft release via release-drafter, then creates and pushes the full and major version git tags.
2. **release_goreleaser** - Runs when `goreleaser-config-path` is set. Builds Go binaries, uploads artifacts to the draft release, and optionally creates attestations.
3. **release_image** - Runs when `image-name` is set. Builds and pushes a multi-platform Docker image, and optionally creates attestations.
4. **release_discussion** - Runs when `create-discussion` is set. Both `discussion-category-id` and `discussion-repository-id` secrets are required if so. Creates a GitHub Discussions announcement.
5. **publish_release** - Runs when `publish` is true and all preceding jobs succeed (or are skipped). Publishes the draft release.

## GoReleaser Configuration

When using the `goreleaser-config-path` input, your GoReleaser config **must** disable release and changelog management since this workflow handles both via release-drafter:

```yaml
release:
  disable: true

changelog:
  disable: true
```

Without these settings, GoReleaser will attempt to create its own GitHub release, conflicting with the draft release created by release-drafter.

## Notes

- The draft-first pattern supports repositories with **immutable releases** enabled. The release is created as a draft, artifacts are uploaded, and only then is it published.
- Artifact attestation requires a **public repository**. Private user-owned or organization repositories on free plans will see a warning and skip attestation automatically.
- To get the discussion repository ID and category ID, use the GitHub CLI (gh) with the following cli and graphql query (replace `OWNER` and `REPO` with the appropriate values):
  - Our former suggested way to get this information, The GraphQL API Explorer](https://docs.github.com/en/graphql/guides/using-graphql-clients), was removed on November 11, 2025.

```
gh api graphql -f query='                                                                                                                                                        7:57:20
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
