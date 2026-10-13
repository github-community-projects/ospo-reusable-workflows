#!/usr/bin/env bash
# Decide whether a workflow run should create a release.
#
# Usage: check-release.sh
#
# Reads its inputs from environment variables, which is how the release
# workflows invoke the inline copy:
#
#   EVENT_NAME     github.event_name of the run.
#   PR_MERGED      github.event.pull_request.merged, for pull_request events.
#   PR_LABELS      Comma-separated labels of the event's pull request.
#   RELEASE_ONLY   "true" to release only on the release label.
#   GITHUB_REPOSITORY, GITHUB_SHA
#                  For push events, the commit whose merged pull request
#                  supplies the labels. Needs gh on PATH and a token in GH_TOKEN.
#   RETRY_DELAY    Seconds to wait before retrying an empty pull request
#                  lookup, default 10. GitHub can take a few seconds to
#                  associate a merged pull request with its commit.
#
# A workflow_dispatch run always releases. A push run releases when the pushed
# commit is the merge commit of a merged pull request that carries a trigger
# label, so a direct push with no pull request does not release. Any other run
# releases when its pull request is merged and carries a trigger label. The
# trigger labels are breaking, feature, vuln, and release, or only release
# when RELEASE_ONLY is true.
#
# Prints should-release=<true|false> on stdout, and writes the same line to
# GITHUB_OUTPUT when that variable is set. Exits 1 when the pull request lookup
# fails, so the caller fails closed instead of skipping a release silently.
set -euo pipefail

event="${EVENT_NAME:-}"
merged="${PR_MERGED:-}"
labels_csv="${PR_LABELS:-}"
release_only="${RELEASE_ONLY:-false}"

finish() {
  echo "should-release=$1"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "should-release=$1" >> "$GITHUB_OUTPUT"
  fi
  exit 0
}

if [ "$event" = "workflow_dispatch" ]; then
  echo "Manual dispatch: releasing" >&2
  finish true
fi

if [ "$event" = "push" ]; then
  repo="${GITHUB_REPOSITORY:-}"
  sha="${GITHUB_SHA:-}"
  if [ -z "$repo" ]; then
    echo "::error::GITHUB_REPOSITORY is required for push events" >&2
    exit 1
  fi
  # The SHA is interpolated into the jq filter, so accept only a full hex SHA.
  if ! [[ "$sha" =~ ^[0-9a-f]{40}$ ]]; then
    echo "::error::GITHUB_SHA '$sha' is not a full commit SHA" >&2
    exit 1
  fi

  # The endpoint also lists open pull requests whose branch contains the
  # commit, so keep only the one this commit merged. Each match prints as
  # "#<number> <labels>" so a pull request without labels is still found.
  filter=".[] | select(.merged_at != null and .merge_commit_sha == \"$sha\") | \"#\(.number) \([.labels[].name] | join(\",\"))\""
  match=""
  for attempt in 1 2; do
    if ! match=$(gh api "repos/$repo/commits/$sha/pulls" --jq "$filter"); then
      echo "::error::could not look up pull requests for $sha in $repo" >&2
      exit 1
    fi
    if [ -n "$match" ] || [ "$attempt" -eq 2 ]; then
      break
    fi
    echo "No merged pull request found for $sha yet: retrying" >&2
    sleep "${RETRY_DELAY:-10}"
  done

  if [ -z "$match" ]; then
    echo "No merged pull request for $sha: skipping release" >&2
    finish false
  fi
  match="${match%%$'\n'*}"
  pr="${match%% *}"
  labels_csv="${match#* }"
  echo "Commit $sha merged pull request $pr" >&2
elif [ "$merged" != "true" ]; then
  echo "PR not merged: skipping release" >&2
  finish false
fi

should_release=false
IFS=',' read -ra labels <<< "${labels_csv,,}"
for label in "${labels[@]}"; do
  if [ "$release_only" = "true" ]; then
    [ "$label" = "release" ] || continue
  else
    case "$label" in
      breaking|feature|vuln|release) ;;
      *) continue ;;
    esac
  fi
  should_release=true
  break
done
echo "PR labels: ${labels_csv}, release-only-with-label: ${release_only}, should-release: ${should_release}" >&2
finish "$should_release"
