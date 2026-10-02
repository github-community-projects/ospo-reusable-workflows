#!/usr/bin/env bash
# Remove Release Drafter's missing-baseline warning from a first release draft.
#
# Release Drafter v7.8.0 appends a "could not find a previous published
# release ... without a comparison baseline" block whenever the repository has
# no published release, even when the workflow passed `from` and the notes are
# complete. Remove this script once a Release Drafter release includes
# https://github.com/release-drafter/release-drafter/pull/1789.
#
# Inputs (environment variables):
#   FROM               Output of first-release-base.sh. When empty, this is not
#                      a first release and the script exits without API calls.
#   RELEASE_ID         Numeric id of the draft release to update.
#   GITHUB_REPOSITORY  owner/name of the repository.
#
# Needs gh and jq on PATH and a token with contents: write in GH_TOKEN. When it
# changes the body, writes it to GITHUB_OUTPUT as body when that variable is
# set. Exits 1 on bad input or a failed API call.
set -euo pipefail

from="${FROM:-}"
release_id="${RELEASE_ID:-}"
repo="${GITHUB_REPOSITORY:-}"

if [ -z "$from" ]; then
  echo "Not a first release; keeping the Release Drafter body"
  exit 0
fi

if [ -z "$repo" ]; then
  echo "::error::GITHUB_REPOSITORY is required" >&2
  exit 1
fi

if ! [[ "$release_id" =~ ^[0-9]+$ ]]; then
  echo "::error::RELEASE_ID must be a numeric release id, got '$release_id'" >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if ! gh api "repos/$repo/releases/$release_id" > "$work/release.json"; then
  echo "::error::could not read release $release_id" >&2
  exit 1
fi

# The block starts with a "---" rule and the warning, and ends at the next rule.
# A draft's tag does not exist yet, and a PATCH without tag_name resets it to
# an "untagged-" placeholder, so send the tag, name, and target back unchanged.
jq '{tag_name, name, target_commitish, body: (.body // "" | sub("\n---\n> \\[!WARNING\\]\n> Release Drafter could not find a previous [\\s\\S]*?\n---\n"; ""))}' \
  "$work/release.json" > "$work/patch.json"

if [ "$(jq -r '.body' "$work/patch.json")" = "$(jq -r '.body // ""' "$work/release.json")" ]; then
  echo "No missing-baseline warning in release $release_id"
  exit 0
fi

if ! gh api --method PATCH "repos/$repo/releases/$release_id" --input "$work/patch.json" > /dev/null; then
  echo "::error::could not update the body of release $release_id" >&2
  exit 1
fi

echo "First release: removed the missing-baseline warning from release $release_id"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  delimiter="body_$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
  {
    echo "body<<$delimiter"
    jq -r '.body' "$work/patch.json"
    echo "$delimiter"
  } >> "$GITHUB_OUTPUT"
fi
