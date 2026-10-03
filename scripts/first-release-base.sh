#!/usr/bin/env bash
# Print the comparison baseline Release Drafter needs for a first release.
#
# Usage: first-release-base.sh [repository]
#
# The repository (owner/name) may also be passed as the GITHUB_REPOSITORY
# environment variable, which is how the release workflows invoke the inline
# copy. Run it from a full (non-shallow) clone. Needs gh on PATH and a token in
# GH_TOKEN.
#
# Release Drafter only lists changes since the last published release, so on a
# repository with none it would write "No changes". When the repository has no
# published (non-draft) release, this prints from=<root commit SHA>, which the
# workflows pass as Release Drafter's `from` input so the first release lists
# every pull request in history. Otherwise it prints an empty from=, and
# Release Drafter compares against the last published release as usual. Writes
# the same line to GITHUB_OUTPUT when that variable is set. Exits 1 when the API
# call fails or the clone is shallow, so the caller fails closed instead of
# guessing.
set -euo pipefail

repo="${1:-${GITHUB_REPOSITORY:-}}"

if [ -z "$repo" ]; then
  echo "::error::usage: first-release-base.sh <owner/repo>" >&2
  exit 1
fi

# --paginate applies --jq to each page, so emit one line per published release
# and test for any output, rather than reading a per-page length.
if ! ids=$(gh api "repos/$repo/releases?per_page=100" --paginate --jq '.[] | select(.draft == false) | .id'); then
  echo "::error::could not list releases for $repo" >&2
  exit 1
fi

from=""
if [ -z "$ids" ]; then
  # A shallow clone's root is the shallow boundary, not the first commit.
  if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
    echo "::error::first release needs full history; check out with fetch-depth: 0" >&2
    exit 1
  fi
  # rev-list lists newest first; with several roots, use the oldest.
  from=$(git rev-list --max-parents=0 HEAD | tail -n 1)
  echo "First release: comparing from root commit $from" >&2
fi

echo "from=$from"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "from=$from" >> "$GITHUB_OUTPUT"
fi
