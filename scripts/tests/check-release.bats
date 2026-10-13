#!/usr/bin/env bats

SHA=0123456789abcdef0123456789abcdef01234567

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../check-release.sh"
  WORK="$(mktemp -d)"
  mkdir "$WORK/bin"
  # Stub gh: log the arguments, print GH_STDOUT_<n> for the nth call (what gh
  # prints after --jq), falling back to GH_STDOUT, and exit with GH_EXIT.
  cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
n=$(wc -l < "$GH_LOG" | tr -d ' ')
var="GH_STDOUT_$n"
printf '%s' "${!var-${GH_STDOUT:-}}"
exit "${GH_EXIT:-0}"
STUB
  chmod +x "$WORK/bin/gh"
  export PATH="$WORK/bin:$PATH"
  export GH_LOG="$WORK/gh.log"
  export GITHUB_OUTPUT="$WORK/output"
  export RETRY_DELAY=0
  unset EVENT_NAME PR_MERGED PR_LABELS RELEASE_ONLY GH_STDOUT GH_EXIT
  export GITHUB_REPOSITORY=owner/repo GITHUB_SHA="$SHA"
  export GITHUB_REF=refs/heads/main DEFAULT_BRANCH=main
}

teardown() {
  rm -rf "$WORK"
}

@test "workflow_dispatch releases" {
  EVENT_NAME=workflow_dispatch run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = "should-release=true" ]
  grep -qx 'should-release=true' "$GITHUB_OUTPUT"
  [ ! -e "$GH_LOG" ]
}

@test "unmerged pull request skips" {
  EVENT_NAME=pull_request_target PR_MERGED=false PR_LABELS=feature run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = "should-release=false" ]
  grep -qx 'should-release=false' "$GITHUB_OUTPUT"
}

@test "merged pull request with a trigger label releases" {
  EVENT_NAME=pull_request_target PR_MERGED=true PR_LABELS=docs,Feature run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = "should-release=true" ]
  [ ! -e "$GH_LOG" ]
}

@test "merged pull request without a trigger label skips" {
  EVENT_NAME=pull_request_target PR_MERGED=true PR_LABELS=docs,chore run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = "should-release=false" ]
}

@test "release-only ignores other trigger labels" {
  EVENT_NAME=pull_request_target PR_MERGED=true PR_LABELS=breaking,feature RELEASE_ONLY=true run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = "should-release=false" ]
}

@test "release-only releases on the release label" {
  EVENT_NAME=pull_request_target PR_MERGED=true PR_LABELS=docs,Release RELEASE_ONLY=true run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = "should-release=true" ]
}

@test "push reads labels from the merged pull request" {
  EVENT_NAME=push GH_STDOUT=$'#12 docs,feature\n' run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = "should-release=true" ]
  grep -qx 'should-release=true' "$GITHUB_OUTPUT"
  [[ "$output" == *"merged pull request #12"* ]]
}

@test "push queries the commit's pull requests filtered to its merge" {
  EVENT_NAME=push GH_STDOUT=$'#12 feature\n' run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -qF "api repos/owner/repo/commits/$SHA/pulls --jq" "$GH_LOG"
  grep -qF ".merged_at != null and .merge_commit_sha == \"$SHA\"" "$GH_LOG"
}

@test "push with a merged pull request without trigger labels skips" {
  EVENT_NAME=push GH_STDOUT=$'#12 docs\n' run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = "should-release=false" ]
}

@test "push with an unlabeled merged pull request skips without retrying" {
  EVENT_NAME=push GH_STDOUT=$'#12 \n' run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = "should-release=false" ]
  [ "$(wc -l < "$GH_LOG")" -eq 1 ]
}

@test "push honors release-only" {
  EVENT_NAME=push RELEASE_ONLY=true GH_STDOUT=$'#12 feature\n' run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = "should-release=false" ]
}

@test "push retries once when the association lags" {
  EVENT_NAME=push GH_STDOUT_1='' GH_STDOUT_2=$'#12 vuln\n' run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = "should-release=true" ]
  [ "$(wc -l < "$GH_LOG")" -eq 2 ]
}

@test "push without a merged pull request skips after one retry" {
  EVENT_NAME=push run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = "should-release=false" ]
  [ "$(wc -l < "$GH_LOG")" -eq 2 ]
  [[ "$output" == *"No merged pull request for $SHA"* ]]
}

@test "push uses the first match when several are returned" {
  EVENT_NAME=push GH_STDOUT=$'#12 docs\n#13 feature\n' run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = "should-release=false" ]
}

@test "push ignores the event's pull request fields" {
  EVENT_NAME=push PR_MERGED=true PR_LABELS=feature GH_STDOUT=$'#12 docs\n' run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = "should-release=false" ]
}

@test "push of a tag skips without a lookup" {
  EVENT_NAME=push GITHUB_REF=refs/tags/v1.2.3 GH_STDOUT=$'#12 feature\n' run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = "should-release=false" ]
  [[ "$output" == *"not the default branch main"* ]]
  [ ! -e "$GH_LOG" ]
}

@test "push to another branch skips without a lookup" {
  EVENT_NAME=push GITHUB_REF=refs/heads/release GH_STDOUT=$'#12 feature\n' run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = "should-release=false" ]
  [ ! -e "$GH_LOG" ]
}

@test "push to a renamed default branch releases" {
  EVENT_NAME=push GITHUB_REF=refs/heads/trunk DEFAULT_BRANCH=trunk GH_STDOUT=$'#12 feature\n' run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = "should-release=true" ]
}

@test "push requires the default branch" {
  unset DEFAULT_BRANCH
  EVENT_NAME=push run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"DEFAULT_BRANCH"* ]]
  [ ! -e "$GH_LOG" ]
}

@test "push API error fails closed" {
  EVENT_NAME=push GH_EXIT=1 run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not look up pull requests"* ]]
  [ ! -s "$GITHUB_OUTPUT" ]
}

@test "push rejects a malformed SHA" {
  EVENT_NAME=push GITHUB_SHA='abc" | .x' run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a full commit SHA"* ]]
  [ ! -e "$GH_LOG" ]
}

@test "push requires a repository" {
  unset GITHUB_REPOSITORY
  EVENT_NAME=push run "$SCRIPT"
  [ "$status" -eq 1 ]
  [ ! -e "$GH_LOG" ]
}

@test "works without GITHUB_OUTPUT" {
  unset GITHUB_OUTPUT
  EVENT_NAME=workflow_dispatch run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$output" = $'Manual dispatch: releasing\nshould-release=true' ]
}
