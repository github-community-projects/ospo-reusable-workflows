#!/usr/bin/env bash
# Check out a merged pull request's merge commit after proving it is on HEAD.
#
# Usage: pin-merge-commit.sh [merge-sha]
#
# The SHA may also be passed as the MERGE_SHA environment variable, which is how
# the release workflows invoke the inline copy. Run it from a full (non-shallow)
# clone of the base branch.
#
# On pull_request_target, checkout v7 refuses merge_commit_sha, so the release
# workflows check out the base branch and call this to move to the merged
# commit. The ancestor check proves the commit is on the base branch, not in a
# fork. Detaches HEAD at the commit, so the version file, tag check, and tags
# all use it. Exits 1 when the SHA is malformed, the clone is shallow, or the
# commit is not an ancestor of HEAD, so the caller fails closed instead of
# releasing a later commit.
set -euo pipefail

sha="${1:-${MERGE_SHA:-}}"

if [ -z "$sha" ]; then
  echo "::error::usage: pin-merge-commit.sh <merge-sha>" >&2
  exit 1
fi

if ! [[ "$sha" =~ ^[0-9a-f]{40}$ ]]; then
  echo "::error::merge commit '$sha' is not a full commit SHA" >&2
  exit 1
fi

# A shallow clone may not reach the merge commit, which would look like a fork.
if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
  echo "::error::pinning the merge commit needs full history; check out with fetch-depth: 0" >&2
  exit 1
fi

head_sha=$(git rev-parse HEAD)
if ! git merge-base --is-ancestor "$sha" HEAD 2>/dev/null; then
  echo "::error::merge commit $sha is not on the checked-out branch (HEAD is $head_sha)" >&2
  exit 1
fi

git checkout --quiet --detach "$sha"
echo "Pinned to merge commit $sha (branch HEAD is $head_sha)"
