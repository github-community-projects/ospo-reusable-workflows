# Release Image Reusable Workflow

> [!CAUTION]
> This workflow has been deprecated and consolidated into the [Release workflow](release.md). Calling `release-image.yaml` directly will fail with an error. Migrate by setting the `image-name` input on `release.yaml` instead.

## Migration

Replace your existing `release-image.yaml` call:

```yaml
# Before (deprecated)
release_image:
  needs: release
  uses: github-community-projects/ospo-reusable-workflows/.github/workflows/release-image.yaml@main
  with:
    image-name: ${{ github.repository }}
    full-tag: ${{ needs.release.outputs.full-tag }}
    short-tag: ${{ needs.release.outputs.short-tag }}
    create-attestation: true
  secrets:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    image-registry: ghcr.io
    image-registry-username: ${{ github.actor }}
    image-registry-password: ${{ secrets.GITHUB_TOKEN }}
```

With the consolidated `release.yaml` inputs:

```yaml
# After
release:
  uses: github-community-projects/ospo-reusable-workflows/.github/workflows/release.yaml@main
  with:
    release-config-name: release-drafter.yaml
    image-name: ${{ github.repository }}
    create-attestation: true
  secrets:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    image-registry-password: ${{ secrets.GITHUB_TOKEN }}
```

Key changes:
- `full-tag` and `short-tag` no longer need to be passed — they are handled internally
- `image-registry` defaults to `ghcr.io`
- `image-registry-username` defaults to `github.actor`
- Registry credentials moved from required secrets to optional (with defaults)

See the full [Release workflow documentation](release.md) for all available inputs.
