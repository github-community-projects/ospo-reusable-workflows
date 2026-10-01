#!/usr/bin/env bash
# Report whether the repository has any published (non-draft) release.
#
# Usage: has-published-release.sh [repository]
#
# The repository (owner/name) may also be passed as the GITHUB_REPOSITORY
# environment variable, which is how the release workflows invoke the inline
# copy. Needs gh on PATH and a token in GH_TOKEN.
#
# Prints published=true or published=false on stdout, and writes the same line
# to GITHUB_OUTPUT when that variable is set. Release Drafter only lists
# changes since the last published release, so the release workflows use this
# to detect a first release. Exits 1 when the API call fails, so the caller
# fails closed instead of guessing.
set -euo pipefail

repo="${1:-${GITHUB_REPOSITORY:-}}"

if [ -z "$repo" ]; then
  echo "::error::usage: has-published-release.sh <owner/repo>" >&2
  exit 1
fi

# --paginate applies --jq to each page, so emit one line per published release
# and test for any output, rather than reading a per-page length.
if ! ids=$(gh api "repos/$repo/releases?per_page=100" --paginate --jq '.[] | select(.draft == false) | .id'); then
  echo "::error::could not list releases for $repo" >&2
  exit 1
fi

if [ -n "$ids" ]; then
  published=true
else
  published=false
fi

echo "published=$published"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "published=$published" >> "$GITHUB_OUTPUT"
fi
