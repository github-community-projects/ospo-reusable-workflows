#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../first-release-notes.sh"
  WORK="$(mktemp -d)"
  mkdir "$WORK/bin"
  # Stub gh: log the arguments. POST prints GH_NOTES and exits GH_POST_EXIT.
  # PATCH saves its --input payload to $WORK/patch.json and exits GH_PATCH_EXIT.
  cat > "$WORK/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
method="" input=""
while [ $# -gt 0 ]; do
  case "$1" in
    --method) method="$2"; shift ;;
    --input) input="$2"; shift ;;
  esac
  shift
done
case "$method" in
  POST)
    printf '%s' "$GH_NOTES"
    exit "${GH_POST_EXIT:-0}"
    ;;
  PATCH)
    cp "$input" "$GH_PATCH"
    exit "${GH_PATCH_EXIT:-0}"
    ;;
esac
exit 99
EOF
  chmod +x "$WORK/bin/gh"
  export PATH="$WORK/bin:$PATH"
  export GH_LOG="$WORK/gh.log" GH_PATCH="$WORK/patch.json"
  export GITHUB_OUTPUT="$WORK/output"
  export GITHUB_REPOSITORY=owner/repo
  export PUBLISHED=false RELEASE_ID=42 TAG=v0.0.1 TARGET_COMMITISH=abc123
  export GH_NOTES='{"name":"v0.0.1","body":"## What'"'"'s Changed\n* first PR by @a in #1"}'
  unset GH_POST_EXIT GH_PATCH_EXIT
}

teardown() {
  rm -rf "$WORK"
}

@test "no published release: body replaced with generated notes" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"replaced the body of release 42"* ]]
  grep -qx 'api --method POST repos/owner/repo/releases/generate-notes -f tag_name=v0.0.1 -f target_commitish=abc123' "$GH_LOG"
  grep -q '^api --method PATCH repos/owner/repo/releases/42 --input ' "$GH_LOG"
  [ "$(jq -r '.body' "$GH_PATCH")" = "$(printf "## What's Changed\n* first PR by @a in #1")" ]
  [ "$(jq -r 'keys | join(",")' "$GH_PATCH")" = "body" ]
}

@test "no published release: body written to GITHUB_OUTPUT" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  head -n 1 "$GITHUB_OUTPUT" | grep -q '^body<<body_[0-9a-f]\{32\}$'
  delimiter=$(head -n 1 "$GITHUB_OUTPUT" | cut -d'<' -f3)
  [ "$(tail -n 1 "$GITHUB_OUTPUT")" = "$delimiter" ]
  grep -qx '\* first PR by @a in #1' "$GITHUB_OUTPUT"
}

@test "target defaults to HEAD" {
  git init -q "$WORK/repo"
  GIT_CONFIG_GLOBAL=/dev/null git -C "$WORK/repo" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m first
  head_sha=$(git -C "$WORK/repo" rev-parse HEAD)
  unset TARGET_COMMITISH
  cd "$WORK/repo"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "target_commitish=$head_sha" "$GH_LOG"
}

@test "a published release exists: no API calls" {
  PUBLISHED=true run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"keeping the Release Drafter body"* ]]
  [ ! -e "$GH_LOG" ]
  [ ! -e "$GITHUB_OUTPUT" ]
}

@test "generate-notes error fails the step" {
  GH_POST_EXIT=1 run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not generate release notes"* ]]
  ! grep -q PATCH "$GH_LOG"
}

@test "generate-notes response without a body fails" {
  GH_NOTES='{"message":"Not Found"}' run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"has no body"* ]]
  ! grep -q PATCH "$GH_LOG"
}

@test "update error fails the step" {
  GH_PATCH_EXIT=1 run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not update the body of release 42"* ]]
  [ ! -e "$GITHUB_OUTPUT" ]
}

@test "body over the GitHub limit is truncated" {
  GH_NOTES=$(jq -n '{body: ("x" * 130000)}')
  export GH_NOTES
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  len=$(jq -r '.body | length' "$GH_PATCH")
  [ "$len" -le 125000 ]
  [[ "$(jq -r '.body' "$GH_PATCH")" == *"_Release notes truncated._" ]]
}

@test "PUBLISHED must be true or false" {
  PUBLISHED="" run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"PUBLISHED must be true or false"* ]]
  [ ! -e "$GH_LOG" ]
}

@test "non-numeric release id is rejected" {
  RELEASE_ID="42; rm -rf /" run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"RELEASE_ID must be numeric"* ]]
  [ ! -e "$GH_LOG" ]
}

@test "missing tag is rejected" {
  TAG="" run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"TAG and GITHUB_REPOSITORY are required"* ]]
  [ ! -e "$GH_LOG" ]
}
