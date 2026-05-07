# Reusable Workflows

> [!IMPORTANT]
> The Release Image and Release Discussion workflows are now deprecated. The have been consolidated into the Release workflow.

This is a placeholder repo for multiple GitHub Actions we use in open source projects.

## Reusable Workflows Available

- [Auto-Labeler](docs/auto-labeler.md)
- [Labeler](docs/labeler.md)
- [Major Version Updater](docs/major-version-updater.md)
- [PR Title](docs/pr-title.md)
- [Release](docs/release.md)
- [Release Image](docs/release-image.md)
- [Release Discussion](docs/release-discussion.md)

> [!CAUTION]
> Check the permissions in each reusable workflow to ensure the GitHub token you pass from your calling workflow meets the required permissions. Most of the time just passing `${{ secrets.GITHUB_TOKEN }}` is sufficient.
> This may require you to go to your repository settings and then Actions to `Actions Permission` and enable reusable workflows. You may also need to update `Workflow Permissions` to `Read and write permissions`.
>
> [Workflows](.github/workflows)

> [!TIP]
> In order to update the semver version of a release both the `release` and a semver label (`major`, `minor`, or `patch`) must be used on the pull request that is merged to `main`.
>
> This is to prevent accidental version bumps from pull requests that are not intended to be releases. (example: Dependabot PRs that label themselves with semver labels)

> [!TIP]
> You can reuse the following files in this repository in your own as they are used by the reusable workflows:
>
> - [labeler.yml](.github/labeler.yml)
> - [release-drafter.yaml](.github/release-drafter.yaml)

> [!NOTE]
> The container image generated in this repo is a placeholder, it contains the files of this repository to ensure it shows "change" and a new container image digest is generated. This allows us to see tagging of the new container image is working and newly generated attestation is related to a new SHA/digest in the [packages view](https://github.com/github-community-projects/ospo-reusable-workflows/pkgs/container/ospo-reusable-workflows).
