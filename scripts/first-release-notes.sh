#!/usr/bin/env bash
# Replace a first release's draft body with GitHub's generated release notes.
#
# Release Drafter finds no pull requests when the repository has no published
# release, so a first release would otherwise ship with "No changes". This
# asks GitHub to generate notes for the tag (with no previous tag, GitHub
# covers the history up to the target commit) and writes them into the draft.
#
# Inputs (environment variables):
#   PUBLISHED          Output of has-published-release.sh. When true, the script
#                      exits without calling the API. Must be true or false.
#   RELEASE_ID         Numeric id of the draft release to update.
#   TAG                Tag the release will use.
#   TARGET_COMMITISH   Commit being released. Defaults to HEAD.
#   GITHUB_REPOSITORY  owner/name of the repository.
#
# Needs gh and jq on PATH and a token with contents: write in GH_TOKEN. When it
# replaces the body, writes it to GITHUB_OUTPUT as body when that variable is
# set. Exits 1 on bad input or a failed API call.
set -euo pipefail

# GitHub rejects release bodies longer than 125000 characters.
max_body=125000

published="${PUBLISHED:-}"
release_id="${RELEASE_ID:-}"
tag="${TAG:-}"
repo="${GITHUB_REPOSITORY:-}"

case "$published" in
  true)
    echo "A published release exists; keeping the Release Drafter body"
    exit 0
    ;;
  false) ;;
  *)
    echo "::error::PUBLISHED must be true or false, got '$published'" >&2
    exit 1
    ;;
esac

if ! [[ "$release_id" =~ ^[0-9]+$ ]]; then
  echo "::error::RELEASE_ID must be numeric, got '$release_id'" >&2
  exit 1
fi

if [ -z "$tag" ] || [ -z "$repo" ]; then
  echo "::error::TAG and GITHUB_REPOSITORY are required" >&2
  exit 1
fi

target="${TARGET_COMMITISH:-$(git rev-parse HEAD)}"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# No previous_tag_name: this is the first release, so there is nothing to diff
# against.
if ! gh api --method POST "repos/$repo/releases/generate-notes" \
  -f tag_name="$tag" \
  -f target_commitish="$target" > "$work/notes.json"; then
  echo "::error::could not generate release notes for $tag" >&2
  exit 1
fi

if ! jq -e '.body | type == "string"' "$work/notes.json" > /dev/null; then
  echo "::error::generate-notes response for $tag has no body" >&2
  exit 1
fi

# Build the PATCH payload with jq and send it with --input so a long body never
# goes through argv.
jq --argjson max "$max_body" '
  .body as $b
  | {body: (if ($b | length) > $max
      then $b[0:($max - 100)] + "\n\n_Release notes truncated._"
      else $b end)}
' "$work/notes.json" > "$work/patch.json"

if ! gh api --method PATCH "repos/$repo/releases/$release_id" --input "$work/patch.json" > /dev/null; then
  echo "::error::could not update the body of release $release_id" >&2
  exit 1
fi

echo "First release: replaced the body of release $release_id with generated notes for $tag"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  delimiter="body_$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
  {
    echo "body<<$delimiter"
    jq -r '.body' "$work/patch.json"
    echo "$delimiter"
  } >> "$GITHUB_OUTPUT"
fi
