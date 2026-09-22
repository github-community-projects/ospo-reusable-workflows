#!/usr/bin/env bash
# Verify that a release tag can be pushed without moving an existing tag.
#
# Usage: check-tag.sh <tag> [remote]
#
# Arguments may also be passed as TAG and REMOTE environment variables, which
# is how the release workflows invoke the inline copy.
#
# Exits 0 when the tag does not exist on the remote, or when it already points
# at HEAD (a re-run of a partially failed release). Exits 1 when the tag exists
# and points elsewhere, or when the remote cannot be queried, so the caller
# fails closed instead of force-pushing over a release.
set -euo pipefail

tag="${1:-${TAG:-}}"
remote="${2:-${REMOTE:-origin}}"

if [ -z "$tag" ]; then
  echo "::error::usage: check-tag.sh <tag> [remote]" >&2
  exit 1
fi

set +e
output=$(git ls-remote --exit-code --tags "$remote" "refs/tags/$tag" "refs/tags/$tag^{}" 2>&1)
status=$?
set -e

case "$status" in
  2)
    echo "Tag $tag does not exist on $remote"
    exit 0
    ;;
  0) ;;
  *)
    echo "::error::git ls-remote failed for $remote (exit $status): $output" >&2
    exit 1
    ;;
esac

# Prefer the peeled line (refs/tags/<tag>^{}) for annotated tags so we compare
# the commit, not the tag object.
remote_sha=$(printf '%s\n' "$output" | awk -v peeled="refs/tags/$tag^{}" -v plain="refs/tags/$tag" '
  $2 == peeled { print $1; found = 1; exit }
  $2 == plain && !found { sha = $1 }
  END { if (!found && sha) print sha }
')

if [ -z "$remote_sha" ]; then
  echo "::error::could not parse git ls-remote output for $tag: $output" >&2
  exit 1
fi

head_sha=$(git rev-parse HEAD)

if [ "$remote_sha" = "$head_sha" ]; then
  echo "Tag $tag already points at HEAD ($head_sha); re-run is safe"
  exit 0
fi

echo "::error::tag $tag already exists on $remote at $remote_sha (HEAD is $head_sha); bump the version before releasing" >&2
exit 1
